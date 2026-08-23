"""Train a MobileNetV2 plant-disease classifier on PlantVillage (38 classes)
and export a float32 TFLite model matching assets/models/plant_disease_labels.txt
(sorted class order). Designed for GitHub Actions ubuntu-latest (4 vCPU, no GPU).
"""
import os
import random
import sys

os.environ["TF_CPP_MIN_LOG_LEVEL"] = "2"

import tensorflow as tf  # noqa: E402

DATA_ROOT = os.environ.get("PV_DIR", "data/pv")
OUT_DIR = "out"
IMG_SIZE = int(os.environ.get("IMG_SIZE", "160"))
CAP_PER_CLASS = int(os.environ.get("CAP_PER_CLASS", "700"))
EPOCHS_HEAD = int(os.environ.get("EPOCHS_HEAD", "3"))
EPOCHS_FT = int(os.environ.get("EPOCHS_FT", "4"))
SEED = 42


def find_class_dir(root):
    """Locate the directory whose immediate subdirs are the 38 class folders."""
    candidates = []
    for dirpath, dirnames, _ in os.walk(root):
        jpgs_any = False
        class_dirs = [d for d in dirnames if not d.startswith(".")]
        if len(class_dirs) >= 38:
            for d in class_dirs[:5]:
                p = os.path.join(dirpath, d)
                for _, _, fs in os.walk(p):
                    if any(f.lower().endswith((".jpg", ".jpeg", ".png")) for f in fs):
                        jpgs_any = True
                    break
                if not jpgs_any:
                    break
            if jpgs_any:
                candidates.append(dirpath)
        if len(candidates) > 1:
            candidates.sort(key=len)  # prefer deepest match later anyway
    if not candidates:
        print("FATAL: could not locate 38-class directory under", root)
        sys.exit(1)
    return max(candidates, key=lambda p: p.count(os.sep))


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    base = find_class_dir(DATA_ROOT)
    class_names = sorted(
        d for d in os.listdir(base)
        if os.path.isdir(os.path.join(base, d)) and not d.startswith(".")
    )
    print("classes:", len(class_names))
    assert len(class_names) == 38, f"expected 38 classes, got {len(class_names)}"

    rng = random.Random(SEED)
    file_paths, labels = [], []
    for idx, cls in enumerate(class_names):
        cdir = os.path.join(base, cls)
        files = [
            os.path.join(cdir, f)
            for f in os.listdir(cdir)
            if f.lower().endswith((".jpg", ".jpeg", ".png"))
        ]
        rng.shuffle(files)
        files = files[:CAP_PER_CLASS]
        file_paths.extend(files)
        labels.extend([idx] * len(files))
    print("images total:", len(file_paths))

    pairs = list(zip(file_paths, labels))
    rng.shuffle(pairs)
    file_paths, labels = [p[0] for p in pairs], [p[1] for p in pairs]

    n_val = max(38 * 10, int(len(file_paths) * 0.08))

    def decode(path, label):
        raw = tf.io.read_file(path)
        img = tf.image.decode_jpeg(raw, channels=3)
        img = tf.image.resize(img, [IMG_SIZE, IMG_SIZE])
        return img, label

    aug = tf.keras.Sequential([
        tf.keras.layers.RandomFlip("horizontal"),
        tf.keras.layers.RandomRotation(0.04),
        tf.keras.layers.RandomZoom(0.08),
        tf.keras.layers.RandomContrast(0.10),
    ])

    def train_map(x, y):
        x = aug(x, training=True)
        x = tf.keras.applications.mobilenet_v2.preprocess_input(x)
        return x, y

    def val_map(x, y):
        x = tf.keras.applications.mobilenet_v2.preprocess_input(x)
        return x, y

    bs = 64
    val_ds = (
        tf.data.Dataset.from_tensor_slices((file_paths[:n_val], labels[:n_val]))
        .map(decode, num_parallel_calls=tf.data.AUTOTUNE)
        .batch(bs)
        .map(val_map, num_parallel_calls=tf.data.AUTOTUNE)
        .prefetch(tf.data.AUTOTUNE)
    )
    train_ds = (
        tf.data.Dataset.from_tensor_slices((file_paths[n_val:], labels[n_val:]))
        .shuffle(min(len(file_paths), 20000), seed=SEED)
        .map(decode, num_parallel_calls=tf.data.AUTOTUNE)
        .batch(bs)
        .map(train_map, num_parallel_calls=tf.data.AUTOTUNE)
        .prefetch(tf.data.AUTOTUNE)
    )

    base_model = tf.keras.applications.MobileNetV2(
        input_shape=(IMG_SIZE, IMG_SIZE, 3), include_top=False, weights="imagenet"
    )
    base_model.trainable = False

    inputs = tf.keras.Input(shape=(IMG_SIZE, IMG_SIZE, 3))
    x = base_model(inputs, training=False)
    x = tf.keras.layers.GlobalAveragePooling2D()(x)
    x = tf.keras.layers.Dropout(0.25)(x)
    outputs = tf.keras.layers.Dense(38, activation="softmax")(x)
    model = tf.keras.Model(inputs, outputs)

    model.compile(
        optimizer=tf.keras.optimizers.Adam(1e-3),
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"],
    )
    ckpt_path = os.path.join(OUT_DIR, "best.keras")
    cbs = [
        tf.keras.callbacks.ModelCheckpoint(ckpt_path, save_best_only=True,
                                           monitor="val_accuracy", mode="max"),
        tf.keras.callbacks.CSVLogger(os.path.join(OUT_DIR, "log.csv")),
    ]

    print("=== stage 1: frozen head training ===")
    model.fit(train_ds, validation_data=val_ds, epochs=EPOCHS_HEAD, callbacks=cbs)

    print("=== stage 2: fine-tune last 40 layers ===")
    base_model.trainable = True
    for layer in base_model.layers[:-40]:
        layer.trainable = False
    model.compile(
        optimizer=tf.keras.optimizers.Adam(1e-5),
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"],
    )
    model.fit(train_ds, validation_data=val_ds,
              epochs=EPOCHS_FT, callbacks=cbs)

    best = tf.keras.models.load_model(ckpt_path)
    loss, acc = best.evaluate(val_ds)
    print(f"FINAL_VAL_ACCURACY={acc:.4f}")

    converter = tf.lite.TFLiteConverter.from_keras_model(best)
    tfl = converter.convert()
    out_model = os.path.join(OUT_DIR, "plant_disease.tflite")
    with open(out_model, "wb") as f:
        f.write(tfl)
    with open(os.path.join(OUT_DIR, "plant_disease_labels.txt"), "w") as f:
        f.write("\n".join(class_names) + "\n")
    print("saved:", out_model, os.path.getsize(out_model), "bytes")


if __name__ == "__main__":
    main()
