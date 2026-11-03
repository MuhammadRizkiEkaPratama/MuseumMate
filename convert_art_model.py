#!/usr/bin/env python3
"""
Download a pre-trained art style classifier from HuggingFace
and convert it to CoreML for MuseumMate (iOS 16.4+).

Run with ml_env active:
  source ~/ml_env/bin/activate
  cd ~/Documents/MuseumMate
  python3 convert_art_model.py
"""

import os, sys
import torch
import coremltools as ct
import numpy as np
from PIL import Image
from pathlib import Path
from transformers import AutoImageProcessor, AutoModelForImageClassification

OUTPUT_DIR  = "/Users/a16/Documents/MuseumMate/MuseumMate/Resources"
OUTPUT_NAME = "ArtStyleClassifier"

# Tried in order — first one that downloads wins
MODEL_CANDIDATES = [
    "google/vit-base-patch16-224",   # general ViT (ImageNet 21k, widely used)
    "microsoft/resnet-50",           # compact fallback
]

ART_STYLE_LABELS = [
    "Impressionism", "Baroque", "Renaissance", "Cubism",
    "Surrealism", "Pop Art", "Romanticism", "Realism",
]


def try_load(name):
    try:
        print(f"  Trying {name} …", flush=True)
        proc  = AutoImageProcessor.from_pretrained(name)
        model = AutoModelForImageClassification.from_pretrained(
            name, ignore_mismatched_sizes=True)
        model.eval()
        print(f"  ✓ Loaded.")
        return model, proc
    except Exception as e:
        print(f"  ✗ {e}")
        return None


def is_art_model(model):
    labels = list(model.config.id2label.values())
    art_kw = {"impression", "baroque", "renaissance", "cubism",
               "surreal", "pop art", "romantic", "realism"}
    return any(any(k in lbl.lower() for k in art_kw) for lbl in labels)


def patch_labels(model):
    if is_art_model(model):
        labels = list(model.config.id2label.values())
        print(f"  ✓ Art labels already present ({len(labels)} classes): {labels[:5]} …")
        return labels

    print("  ℹ Replacing classifier head with 8 art style outputs …")
    n = len(ART_STYLE_LABELS)
    model.config.id2label = {i: lbl for i, lbl in enumerate(ART_STYLE_LABELS)}
    model.config.label2id = {lbl: i for i, lbl in enumerate(ART_STYLE_LABELS)}

    if hasattr(model, "classifier"):
        head = model.classifier
        if isinstance(head, torch.nn.Linear):
            model.classifier = torch.nn.Linear(head.in_features, n)
            torch.nn.init.xavier_uniform_(model.classifier.weight)
        elif hasattr(head, "__len__"):
            old = head[-1]
            head[-1] = torch.nn.Linear(old.in_features, n)
            torch.nn.init.xavier_uniform_(head[-1].weight)
    elif hasattr(model, "fc"):
        old = model.fc
        model.fc = torch.nn.Linear(old.in_features, n)
        torch.nn.init.xavier_uniform_(model.fc.weight)
    else:
        print("  ⚠ Classifier head not found — labels patched in config only.")

    print(f"  ✓ Output head → {n} art style labels.")
    return ART_STYLE_LABELS


class LogitsWrapper(torch.nn.Module):
    """Strip the HuggingFace output dict — return only the logits tensor."""
    def __init__(self, m):
        super().__init__()
        self.m = m
    def forward(self, x):
        return self.m(x).logits


def export(model, proc, labels):
    dummy  = Image.fromarray(np.zeros((224, 224, 3), dtype=np.uint8))
    inputs = proc(images=dummy, return_tensors="pt")
    tensor = inputs["pixel_values"]

    print("  Tracing model with torch.jit.trace …", flush=True)
    wrapper = LogitsWrapper(model)
    with torch.no_grad():
        traced = torch.jit.trace(wrapper, tensor, strict=False)

    print("  Converting to CoreML (iOS 16 mlprogram) …", flush=True)
    mlmodel = ct.convert(
        traced,
        inputs=[ct.ImageType(
            name="image",
            shape=tensor.shape,
            scale=1 / 255.0,
            bias=[-0.485 / 0.229, -0.456 / 0.224, -0.406 / 0.225],
            color_layout=ct.colorlayout.RGB,
        )],
        classifier_config=ct.ClassifierConfig(labels),
        minimum_deployment_target=ct.target.iOS16,
        convert_to="mlprogram",
    )
    mlmodel.short_description = "Art Style Classifier — MuseumMate"
    mlmodel.author  = "MuseumMate / HuggingFace"
    mlmodel.version = "1.0"
    return mlmodel


def save(mlmodel):
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    out = os.path.join(OUTPUT_DIR, f"{OUTPUT_NAME}.mlpackage")
    mlmodel.save(out)
    size_mb = sum(
        f.stat().st_size for f in Path(out).rglob("*") if f.is_file()
    ) / 1024 / 1024
    print(f"\n✅  Saved → {out}  ({size_mb:.1f} MB)")
    print("\nNext: drag ArtStyleClassifier.mlpackage into Xcode → Resources group")
    print("      check 'MuseumMate' target membership → Build\n")


def main():
    print("=" * 60)
    print(" MuseumMate — Art Classifier → CoreML Converter")
    print("=" * 60)

    result = None
    for name in MODEL_CANDIDATES:
        result = try_load(name)
        if result:
            break

    if result is None:
        print("\n✗ No model loaded. Try activating VPN and re-running.")
        sys.exit(1)

    model, proc = result
    labels = patch_labels(model)
    mlmodel = export(model, proc, labels)
    save(mlmodel)


if __name__ == "__main__":
    main()
