# Lối tắt cho các script trong scripts/. Gõ `make` để xem danh sách.

.PHONY: help bootstrap check test build debug snapshot install uninstall release clean

help:
	@echo "Mr TV — các lệnh thường dùng:"
	@echo "  make bootstrap                 cài Rust và XcodeGen (một lần)"
	@echo "  make check                     kiểm tra công cụ, định dạng mã, clippy, toàn bộ bài thử"
	@echo "  make test                      chỉ chạy bài thử"
	@echo "  make build                     build bản Release vào build/Release/MrTV.app"
	@echo "  make debug                     build bản Debug"
	@echo "  make snapshot                  chụp mọi màn (sáng, tối) vào build/snapshots để so với thiết kế"
	@echo "  make install                   build và để MrTV.app trong thư mục dự án"
	@echo "  make uninstall                 gỡ Mr TV khỏi máy (giữ gõ tắt)"
	@echo "  make release VERSION=0.1.0     đóng gói bản phát hành vào dist/"
	@echo "  make release VERSION=0.1.0 PUBLISH=1   đóng gói rồi tạo bản nháp trên GitHub"
	@echo "  make clean                     xoá mọi thứ sinh ra khi build"

bootstrap:
	@scripts/bootstrap.sh

check:
	@scripts/check.sh

test:
	@scripts/test.sh

build:
	@scripts/build.sh

debug:
	@scripts/build.sh debug

snapshot:
	@scripts/build.sh debug
	@build/Debug/MrTV.app/Contents/MacOS/MrTV --snapshot build/snapshots

install:
	@scripts/install-dev.sh

uninstall:
	@scripts/uninstall.sh

release:
	@test -n "$(VERSION)" || (echo "Thiếu VERSION, ví dụ: make release VERSION=0.1.0" && exit 2)
	@scripts/release.sh $(VERSION) $(if $(PUBLISH),--publish,)

clean:
	rm -rf build Frameworks dist apple/MrTV.xcodeproj
	cd core && cargo clean
