#!/usr/bin/env sh
set -eu
flutter create --platforms=windows,linux --project-name local_store_management --org com.maydayalaska .
flutter pub get
echo 'Runner desktop Flutter generati. Ora puoi usare: flutter run -d linux'
