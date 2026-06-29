# Example — Flutter card preview (device-free)

A minimal Flutter app that loads a **bundled fixture** (`assets/sample_ocr.json`,
the OCR lines of `IMG_3379`), runs it through `costco_price_tag_parser`, and renders
the result as a card. **No camera, no ML Kit** — so it runs on web/desktop with no
device. Handy for screenshots and quick visual checks.

```bash
flutter pub get
flutter run -d chrome     # or: flutter run -d macos
```

For the real on-device camera → ML Kit → parser flow, see
[`flutter_camera_demo`](../flutter_camera_demo).
