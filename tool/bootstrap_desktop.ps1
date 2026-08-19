$ErrorActionPreference = 'Stop'
flutter create --platforms=windows,linux --project-name local_store_management --org com.maydayalaska .
flutter pub get
Write-Host 'Runner desktop Flutter generati. Ora puoi usare: flutter run -d windows'
