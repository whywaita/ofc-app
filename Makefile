.PHONY: help analyze test build ci format app-run app-analyze app-test app-build app-build-web app-build-web-pages core-analyze core-test app-ios-open verify-web verify-web-list verify-web-setup verify-web-suppressions serve-web-verify

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
	@echo "  make verify-web-setup # npm ci + playwright chromium (初回のみ)"
	@echo "  make verify-web    # flutter build web + vlmkit gates (docs/vlmkit.md)"
	@echo "  make verify-web-list # 実行される gate 一覧 (サーバは起動しない)"
	@echo "  make serve-web-verify # 検証用サーバだけ起動 (手動で触る用)"

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

# --- Web verification (vlmkit) ---
# vlmkit measures the DOM; a Flutter web build renders into a canvas, so the DOM is empty
# until the accessibility tree is switched on. tools/vlmkit/serve-web.mjs does that when it
# serves the bundle, which is why these targets do not use a plain static server.
# See docs/vlmkit.md for what each gate can and cannot see.
NODE ?= node

verify-web-setup:
	npm ci
	npx playwright install chromium

verify-web-list:
	npx vlmkit gates list

verify-web-suppressions:
	npx vlmkit gates suppressions

serve-web-verify: app-build-web
	$(NODE) tools/vlmkit/serve-web.mjs

verify-web: app-build-web
	npx vlmkit gates run
