.PHONY: help analyze test build ci format app-run app-analyze app-test app-build app-build-web app-build-web-pages core-analyze core-test app-ios-open

DART ?= dart
FLUTTER ?= flutter
DARTRUN := $(DART) --disable-analytics
FLUTTERRUN := $(FLUTTER) --suppress-analytics
APP_DIR ?= app

help:
	@echo "Available tasks:"
	@echo "  make analyze       # dart analyze (root) + flutter analyze (app)"
	@echo "  make test          # dart test (root) + flutter test (app)"
	@echo "  make build         # flutter build bundle (app)"
	@echo "  make ci            # analyze + test + build"
	@echo "  make format        # dart format (root & app)"
	@echo "  make app-run       # flutter run (app). DEVICE?=ios 例: make app-run DEVICE=\"iPhone 15\""
	@echo "  make app-build-web # flutter build web (static files -> app/build/web)"
	@echo "  make app-build-web-pages BASE_HREF=/repo/ # flutter build web with base-href for GitHub Pages"
	@echo "  make app-ios-open  # Xcode workspace を開く (app/ios/Runner.xcworkspace)"

analyze: core-analyze app-analyze

test: core-test app-test

build: app-build

ci: analyze test build

core-analyze:
	HOME=$(PWD) $(DARTRUN) analyze

core-test:
	HOME=$(PWD) $(DARTRUN) test -r expanded

app-analyze:
	cd $(APP_DIR) && $(FLUTTERRUN) pub get && HOME=$$(pwd) $(FLUTTERRUN) analyze

app-test:
	cd $(APP_DIR) && HOME=$$(pwd) $(FLUTTERRUN) test -r expanded

app-build:
	cd $(APP_DIR) && HOME=$$(pwd) $(FLUTTERRUN) build bundle

app-build-web:
	cd $(APP_DIR) && HOME=$$(pwd) $(FLUTTERRUN) build web --release

app-build-web-pages:
	cd $(APP_DIR) && HOME=$$(pwd) $(FLUTTERRUN) build web --release --base-href "$(BASE_HREF)"

format:
	HOME=$(PWD) $(DARTRUN) format --set-exit-if-changed .
	cd $(APP_DIR) && HOME=$$(pwd) $(DARTRUN) format --set-exit-if-changed .

app-run:
	cd $(APP_DIR) && $(FLUTTERRUN) run -d $(DEVICE)

app-ios-open:
	cd $(APP_DIR) && open ios/Runner.xcworkspace
