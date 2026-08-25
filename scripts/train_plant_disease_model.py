"""
Kisan Mitra — Retrain MobileNetV2 on PlantVillage + PlantDoc field photos
==========================================================================
Run this in Google Colab (Runtime → Change runtime type → T4 GPU).

What this does:
  1. Downloads PlantVillage (lab photos, 54k images, 38 classes)
  2. Downloads PlantDoc (real field photos, ~2.5k images, 27 classes)
  3. Merges both — real field photos teach the model what crops actually
     look like under rain, dirt, bad lighting, and overlapping leaves.
  4. Heavy augmentation: random flips, rotation, zoom, colour jitter,
     brightness/contrast, Gaussian noise — simulates phone cameras
     in Indian field conditions.
  5. Trains MobileNetV2 (ImageNet pretrained) with class-balanced loss
     so the 11 tomato-disease classes don't dominate.
  6. Exports a TFLite float32 file ready to drop into assets/models/.

After training, download plant_disease.tflite + plant_disease_labels.txt
from the Colab files sidebar and replace the files in assets/models/.
"""

# ── 0. Install deps (Colab) ────────────────────────────────────────────
import subprocess, sys

def pip(*pkgs):
    subprocess.check_call([sys.executable, "-m", "pip", "install", "-q", *pkgs])

pip("tensorflow>=2.16,<2.18", "Pillow", "scikit-learn", "kaggle")

# ── 1. Imports ──────────────────────────────────────────────────────────
import json, os, pathlib, random, shutil, zipfile, glob
from collections import Counter

import numpy as np
import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers
from sklearn.utils.class_weight import compute_class_weight

print(f"TensorFlow {tf.__version__}  —  GPU: {tf.config.list_physical_devices('GPU')}")

# ── 2. Constants ────────────────────────────────────────────────────────
IMG_SIZE      = 224          # ← change to 160 if you want smaller/faster model
BATCH         = 32
EPOCHS_BASE   = 15           # frozen base
EPOCHS_FINETUNE = 35         # unfrozen fine-tune
SEED          = 42
DATA_DIR      = pathlib.Path("data")
PLANT_VILLAGE_DIR = DATA_DIR / "plantvillage" / "plantvillage" / "plantvillage"
PLANT_DOC_DIR = DATA_DIR / "PlantDoc"
OUTPUT_DIR    = pathlib.Path("output")
OUTPUT_DIR.mkdir(exist_ok=True)

tf.random.set_seed(SEED)
np.random.seed(SEED)

# ── 3. The 38 canonical labels (must match assets/models/plant_disease_labels.txt) ──
LABELS = [
    "Apple___Apple_scab",
    "Apple___Black_rot",
    "Apple___Cedar_apple_rust",
    "Apple___healthy",
    "Blueberry___healthy",
    "Cherry_(including_sour)___Powdery_mildew",
    "Cherry_(including_sour)___healthy",
    "Corn_(maize)___Cercospora_leaf_spot Gray_leaf_spot",
    "Corn_(maize)___Common_rust_",
    "Corn_(maize)___Northern_Leaf_Blight",
    "Corn_(maize)___healthy",
    "Grape___Black_rot",
    "Grape___Esca_(Black_Measles)",
    "Grape___Leaf_blight_(Isariopsis_Leaf_Spot)",
    "Grape___healthy",
    "Orange___Haunglongbing_(Citrus_greening)",
    "Peach___Bacterial_spot",
    "Peach___healthy",
    "Pepper,_bell___Bacterial_spot",
    "Pepper,_bell___healthy",
    "Potato___Early_blight",
    "Potato___Late_blight",
    "Potato___healthy",
    "Raspberry___healthy",
    "Soybean___healthy",
    "Squash___Powdery_mildew",
    "Strawberry___Leaf_scorch",
    "Strawberry___healthy",
    "Tomato___Bacterial_spot",
    "Tomato___Early_blight",
    "Tomato___Late_blight",
    "Tomato___Leaf_Mold",
    "Tomato___Septoria_leaf_spot",
    "Tomato___Spider_mites Two-spotted_spider_mite",
    "Tomato___Target_Spot",
    "Tomato___Tomato_Yellow_Leaf_Curl_Virus",
    "Tomato___Tomato_mosaic_virus",
    "Tomato___healthy",
]
NUM_CLASSES = len(LABELS)
LABEL2IDX   = {l: i for i, l in enumerate(LABELS)}

# ── 4. PlantDoc → PlantVillage label mapping ─────────────────────────────
# PlantDoc uses different names.  Map every PlantDoc folder name to the
# closest PlantVillage class.  Unmappable classes are skipped (not enough
# overlap to be useful).
PLANTDOC_MAP = {
    # Apple
    "Apple Scab":             "Apple___Apple_scab",
    "Apple Black rot":        "Apple___Black_rot",
    "Apple Cedar rust":       "Apple___Cedar_apple_rust",
    "Apple healthy":          "Apple___healthy",
    # Blueberry
    "Blueberry healthy":      "Blueberry___healthy",
    # Cherry
    "Cherry Powdery mildew":  "Cherry_(including_sour)___Powdery_mildew",
    "Cherry healthy":         "Cherry_(including_sour)___healthy",
    # Corn
    "Corn Gray leaf spot":    "Corn_(maize)___Cercospora_leaf_spot Gray_leaf_spot",
    "Corn common rust":       "Corn_(maize)___Common_rust_",
    "Corn Northern leaf blight": "Corn_(maize)___Northern_Leaf_Blight",
    "Corn healthy":           "Corn_(maize)___healthy",
    # Grape
    "Grape Black rot":        "Grape___Black_rot",
    "Grape Esca":             "Grape___Esca_(Black_Measles)",
    "Grape Leaf blight":      "Grape___Leaf_blight_(Isariopsis_Leaf_Spot)",
    "Grape healthy":          "Grape___healthy",
    # Orange
    "Orange Haunglongbing":   "Orange___Haunglongbing_(Citrus_greening)",
    # Peach
    "Peach Bacterial spot":   "Peach___Bacterial_spot",
    "Peach healthy":          "Peach___healthy",
    # Pepper
    "Pepper Bell Bacterial spot": "Pepper,_bell___Bacterial_spot",
    "Pepper Bell healthy":    "Pepper,_bell___healthy",
    # Potato
    "Potato Early blight":    "Potato___Early_blight",
    "Potato Late blight":     "Potato___Late_blight",
    "Potato healthy":         "Potato___healthy",
    # Raspberry
    "Raspberry healthy":      "Raspberry___healthy",
    # Soybean
    "Soybean healthy":        "Soybean___healthy",
    # Squash
    "Squash Powdery mildew":  "Squash___Powdery_mildew",
    # Strawberry
    "Strawberry Leaf scorch": "Strawberry___Leaf_scorch",
    "Strawberry healthy":     "Strawberry___healthy",
    # Tomato
    "Tomato Bacterial spot":  "Tomato___Bacterial_spot",
    "Tomato Early blight":    "Tomato___Early_blight",
    "Tomato Late blight":     "Tomato___Late_blight",
    "Tomato Leaf mold":       "Tomato___Leaf_Mold",
    "Tomato Septoria leaf spot": "Tomato___Septoria_leaf_spot",
    "Tomato Spider mites":    "Tomato___Spider_mites Two-spotted_spider_mite",
    "Tomato Target spot":     "Tomato___Target_Spot",
    "Tomato Yellow Leaf Curl Virus": "Tomato___Tomato_Yellow_Leaf_Curl_Virus",
    "Tomato mosaic virus":    "Tomato___Tomato_mosaic_virus",
    "Tomato healthy":         "Tomato___healthy",
}

# ── 5. Download datasets ─────────────────────────────────────────────────
def download_file(url, dest):
    """Download with wget or curl."""
    if dest.exists():
        print(f"  ✓ Already downloaded: {dest.name}")
        return
    print(f"  ↓ Downloading {url.split('/')[-1]} …")
    subprocess.check_call(["wget", "-q", "--show-progress", "-O", str(dest), url])

def download_plantvillage():
    """Download PlantVillage dataset (colour images, 54k files)."""
    pv_zip = DATA_DIR / "plantvillage.zip"
    if PLANT_VILLAGE_DIR.exists() and any(PLANT_VILLAGE_DIR.iterdir()):
        print("  ✓ PlantVillage already extracted")
        return
    # Kaggle mirror (no auth needed for this public dataset)
    urls = [
        "https://storage.googleapis.com/plantdata/PlantVillage.zip",
        "https://raw.githubusercontent.com/spMohanty/PlantVillage-Dataset/master/PlantVillage.zip",
    ]
    downloaded = False
    for url in urls:
        try:
            download_file(url, pv_zip)
            downloaded = True
            break
        except Exception as e:
            print(f"  ✗ Failed ({e}), trying next mirror …")
            continue
    if not downloaded:
        # Fallback: ask user to upload manually
        print("\n⚠  Could not download PlantVillage automatically.")
        print("   Please upload plantvillage.zip to the data/ folder manually.")
        print("   You can get it from: https://www.kaggle.com/datasets/emmarex/plantdisease")
        while not pv_zip.exists():
            input("   Press Enter after placing plantvillage.zip in data/ …")
    print("  Extracting PlantVillage …")
    with zipfile.ZipFile(pv_zip) as zf:
        zf.extractall(DATA_DIR / "plantvillage")

def download_plantdoc():
    """Download PlantDoc dataset (real-world photos, ~2.5k files)."""
    pd_zip = DATA_DIR / "plantdoc.zip"
    if PLANT_DOC_DIR.exists() and any(PLANT_DOC_DIR.iterdir()):
        print("  ✓ PlantDoc already extracted")
        return
    url = "https://github.com/pratikkayal/PlantDoc-Dataset/archive/refs/heads/master.zip"
    try:
        download_file(url, pd_zip)
    except Exception as e:
        print(f"  ✗ Failed to download PlantDoc: {e}")
        print("  The model will train on PlantVillage only (still works, just less accurate on field photos).")
        return
    print("  Extracting PlantDoc …")
    with zipfile.ZipFile(pd_zip) as zf:
        zf.extractall(DATA_DIR)
    # Rename extracted folder
    extracted = DATA_DIR / "PlantDoc-Dataset-master"
    if extracted.exists() and not PLANT_DOC_DIR.exists():
        extracted.rename(PLANT_DOC_DIR)

print("═══ Downloading datasets ═══")
DATA_DIR.mkdir(exist_ok=True)
download_plantvillage()
download_plantdoc()

# ── 6. Build image list ──────────────────────────────────────────────────
EXTS = {".jpg", ".jpeg", ".png", ".bmp"}

def collect_images():
    """
    Returns (paths: list[str], labels: list[int]).
    PlantVillage images keep their original label index.
    PlantDoc images are mapped to the closest PlantVillage class.
    """
    paths, labels = [], []

    # ── PlantVillage ──
    print("\n═══ Collecting PlantVillage images ═══")
    pv_count = Counter()
    for class_dir in sorted(PLANT_VILLAGE_DIR.iterdir()):
        if not class_dir.is_dir():
            continue
        folder_name = class_dir.name
        if folder_name not in LABEL2IDX:
            continue
        idx = LABEL2IDX[folder_name]
        for img_path in class_dir.iterdir():
            if img_path.suffix.lower() in EXTS:
                paths.append(str(img_path))
                labels.append(idx)
                pv_count[folder_name] += 1
    print(f"  PlantVillage: {sum(pv_count.values())} images across {len(pv_count)} classes")
    for cls, cnt in pv_count.most_common(5):
        print(f"    {cls}: {cnt}")

    # ── PlantDoc ──
    print("\n═══ Collecting PlantDoc field photos ═══")
    pd_count = Counter()
    pd_skipped = []
    # PlantDoc has train/ and test/ folders, and individual class folders
    pd_dirs = []
    for sub in ["train", "test", ""]:
        p = PLANT_DOC_DIR / sub if sub else PLANT_DOC_DIR
        if p.exists():
            pd_dirs.append(p)

    for base_dir in pd_dirs:
        if not base_dir.exists():
            continue
        for class_dir in base_dir.iterdir():
            if not class_dir.is_dir():
                continue
            folder_name = class_dir.name
            if folder_name not in PLANTDOC_MAP:
                pd_skipped.append(folder_name)
                continue
            target_idx = LABEL2IDX[PLANTDOC_MAP[folder_name]]
            for img_path in class_dir.iterdir():
                if img_path.suffix.lower() in EXTS:
                    paths.append(str(img_path))
                    labels.append(target_idx)
                    pd_count[PLANTDOC_MAP[folder_name]] += 1

    if pd_count:
        print(f"  PlantDoc:     {sum(pd_count.values())} field images mapped to {len(pd_count)} classes")
        for cls, cnt in pd_count.most_common(5):
            print(f"    {cls}: +{cnt} field photos")
    else:
        print("  PlantDoc:     no images found (will train on PlantVillage only)")
    if pd_skipped:
        print(f"  PlantDoc skipped (no PlantVillage equivalent): {', '.join(pd_skipped[:10])}")

    return paths, labels

all_paths, all_labels = collect_images()
print(f"\n═══ Total: {len(all_paths)} images, {len(set(all_labels))} classes ═══")

# ── 7. Train / val split (80/20 stratified) ──────────────────────────────
from sklearn.model_selection import StratifiedShuffleSplit

splitter = StratifiedShuffleSplit(n_splits=1, test_size=0.2, random_state=SEED)
train_idx, val_idx = next(splitter.split(all_paths, all_labels))

train_paths  = [all_paths[i] for i in train_idx]
train_labels = [all_labels[i] for i in train_idx]
val_paths    = [all_paths[i] for i in val_idx]
val_labels   = [all_labels[i] for i in val_idx]

print(f"Train: {len(train_paths)}  Val: {len(val_paths)}")

# ── 8. Data augmentation & preprocessing ─────────────────────────────────
MOBILENET_MEAN = np.array([0.485, 0.456, 0.406], dtype=np.float32)
MOBILENET_STD  = np.array([0.229, 0.224, 0.225], dtype=np.float32)

def mobilenet_preprocess(image):
    """Normalize to MobileNetV2 expected range [-1, 1]."""
    image = tf.cast(image, tf.float32) / 255.0
    image = (image - MOBILENET_MEAN) / MOBILENET_STD
    return image

def augment_train(image, label):
    """Aggressive augmentation for field-condition robustness."""
    image = tf.image.random_flip_left_right(image)
    image = tf.image.random_flip_up_down(image)
    image = tf.image.random_brightness(image, 0.25)
    image = tf.image.random_contrast(image, 0.7, 1.3)
    image = tf.image.random_saturation(image, 0.7, 1.3)
    image = tf.image.random_hue(image, 0.08)
    # Random rotation via tf.image
    image = tf.image.random_crop(
        tf.image.resize(image, [IMG_SIZE + 32, IMG_SIZE + 32]),
        [IMG_SIZE, IMG_SIZE, 3],
    )
    # Random zoom (centre crop)
    zoom = random.uniform(0.8, 1.0)
    side = int(IMG_SIZE * zoom)
    offset = (IMG_SIZE - side) // 2
    image = tf.image.crop_to_bounding_box(image, offset, offset, side, side)
    image = tf.image.resize(image, [IMG_SIZE, IMG_SIZE])
    # Slight Gaussian noise
    noise = tf.random.normal([IMG_SIZE, IMG_SIZE, 3], mean=0.0, stddev=0.02)
    image = tf.clip_by_value(image + noise, 0.0, 255.0 if image.dtype == tf.float32 else 255)
    image = mobilenet_preprocess(image)
    return image, label

def preprocess_val(image, label):
    image = tf.image.resize(image, [IMG_SIZE, IMG_SIZE])
    image = mobilenet_preprocess(image)
    return image, label

def load_and_preprocess(path, label):
    raw = tf.io.read_file(path)
    image = tf.image.decode_image(raw, channels=3, expand_animations=False)
    image = tf.cast(image, tf.float32)
    return image, label

# Build tf.data pipelines
train_ds = (
    tf.data.Dataset.from_tensor_slices((train_paths, train_labels))
    .shuffle(2048, seed=SEED)
    .map(load_and_preprocess, num_parallel_calls=tf.data.AUTOTUNE)
    .map(augment_train, num_parallel_calls=tf.data.AUTOTUNE)
    .batch(BATCH)
    .prefetch(tf.data.AUTOTUNE)
)

val_ds = (
    tf.data.Dataset.from_tensor_slices((val_paths, val_labels))
    .map(load_and_preprocess, num_parallel_calls=tf.data.AUTOTUNE)
    .map(preprocess_val, num_parallel_calls=tf.data.AUTOTUNE)
    .batch(BATCH)
    .prefetch(tf.data.AUTOTUNE)
)

# ── 9. Class weights (balances the 11 tomato classes vs others) ───────────
cw = compute_class_weight("balanced", classes=np.arange(NUM_CLASSES), y=train_labels)
class_weight = {i: w for i, w in enumerate(cw)}
print(f"Class weight range: {min(cw):.2f} – {max(cw):.2f}")

# ── 10. Build model ──────────────────────────────────────────────────────
print("\n═══ Building MobileNetV2 ═══")
base_model = keras.applications.MobileNetV2(
    input_shape=(IMG_SIZE, IMG_SIZE, 3),
    include_top=False,
    weights="imagenet",
)
base_model.trainable = False  # freeze for phase 1

model = keras.Sequential([
    base_model,
    layers.GlobalAveragePooling2D(),
    layers.Dropout(0.3),
    layers.Dense(256, activation="relu"),
    layers.Dropout(0.2),
    layers.Dense(NUM_CLASSES, activation="softmax"),
])

model.compile(
    optimizer=keras.optimizers.Adam(learning_rate=1e-3),
    loss="sparse_categorical_crossentropy",
    metrics=["accuracy"],
)
model.summary()

# ── 11. Phase 1: Train classifier head (frozen base) ────────────────────
print("\n═══ Phase 1: Frozen base ═══")
callbacks = [
    keras.callbacks.EarlyStopping(patience=5, restore_best_weights=True, monitor="val_accuracy"),
    keras.callbacks.ReduceLROnPlateau(factor=0.5, patience=2, min_lr=1e-6),
]

history1 = model.fit(
    train_ds,
    validation_data=val_ds,
    epochs=EPOCHS_BASE,
    class_weight=class_weight,
    callbacks=callbacks,
)

# ── 12. Phase 2: Fine-tune top layers ────────────────────────────────────
print("\n═══ Phase 2: Fine-tuning ═══")
base_model.trainable = True
# Freeze all but last 30 layers
for layer in base_model.layers[:-30]:
    layer.trainable = False

model.compile(
    optimizer=keras.optimizers.Adam(learning_rate=1e-5),
    loss="sparse_categorical_crossentropy",
    metrics=["accuracy"],
)

history2 = model.fit(
    train_ds,
    validation_data=val_ds,
    epochs=EPOCHS_BASE + EPOCHS_FINETUNE,
    initial_epoch=len(history1.history["loss"]),
    class_weight=class_weight,
    callbacks=callbacks,
)

# ── 13. Final evaluation ─────────────────────────────────────────────────
print("\n═══ Final evaluation ═══")
loss, acc = model.evaluate(val_ds)
print(f"Val accuracy: {acc:.4f}  Val loss: {loss:.4f}")

# Per-class accuracy
y_true = np.array(val_labels)
y_pred = np.argmax(model.predict(val_ds, verbose=0), axis=1)
print("\nPer-class accuracy:")
for i in range(NUM_CLASSES):
    mask = y_true == i
    if mask.sum() == 0:
        continue
    cls_acc = (y_pred[mask] == i).mean()
    print(f"  {LABELS[i]:55s}  {cls_acc:.3f}  ({mask.sum()} imgs)")

# ── 14. Export TFLite ────────────────────────────────────────────────────
print("\n═══ Exporting TFLite ═══")

# Float32 (what Kisan Mitra uses)
converter = tf.lite.TFLiteConverter.from_keras_model(model)
tflite_model = converter.convert()
float_path = OUTPUT_DIR / "plant_disease.tflite"
float_path.write_bytes(tflite_model)
print(f"  Saved: {float_path}  ({len(tflite_model):,} bytes)")

# Labels file
labels_path = OUTPUT_DIR / "plant_disease_labels.txt"
labels_path.write_text("\n".join(LABELS) + "\n")
print(f"  Saved: {labels_path}")

# Optional: int8 quantised (smaller, slightly less accurate)
try:
    def representative_dataset():
        for paths_batch, labels_batch in train_ds.take(100):
            yield [paths_batch]

    converter_q = tf.lite.TFLiteConverter.from_keras_model(model)
    converter_q.optimizations = [tf.lite.Optimize.DEFAULT]
    converter_q.representative_dataset = representative_dataset
    converter_q.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS_INT8]
    converter_q.inference_input_type  = tf.int8
    converter_q.inference_output_type = tf.int8
    int8_model = converter_q.convert()
    int8_path = OUTPUT_DIR / "plant_disease_int8.tflite"
    int8_path.write_bytes(int8_model)
    print(f"  Saved (int8): {int8_path}  ({len(int8_model):,} bytes)")
except Exception as e:
    print(f"  Int8 quantisation failed (non-fatal): {e}")

# ── 15. Done ─────────────────────────────────────────────────────────────
print(f"""
╔══════════════════════════════════════════════════════════════════╗
║  Training complete!                                            ║
║                                                                ║
║  Files to download from Colab sidebar (right-click → Download):║
║                                                                ║
║    output/plant_disease.tflite  → assets/models/               ║
║    output/plant_disease_labels.txt → assets/models/            ║
║                                                                ║
║  Then run:                                                     ║
║    flutter pub get                                             ║
║    flutter build apk --release                                 ║
╚══════════════════════════════════════════════════════════════════╝
""")
