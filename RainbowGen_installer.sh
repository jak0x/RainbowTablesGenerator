#!/bin/bash

# rainbowgen_installer.sh - Crea un paquete .deb para instalar RainbowGen como herramienta CLI

APP_NAME="rainbowgen"
VERSION="1.0"
ARCH="amd64"
PKG_DIR="${APP_NAME}_${VERSION}"

# Crear estructura de directorios Debian
mkdir -p $PKG_DIR/usr/local/bin
mkdir -p $PKG_DIR/DEBIAN
mkdir -p $PKG_DIR/usr/share/${APP_NAME}

# Copiar archivos necesarios
cp rainbow_gen_parallel_s3.sh $PKG_DIR/usr/local/bin/$APP_NAME
chmod +x $PKG_DIR/usr/local/bin/$APP_NAME
cp -r rainbowcrack $PKG_DIR/usr/share/${APP_NAME}/

# Crear archivo de control
cat <<EOF > $PKG_DIR/DEBIAN/control
Package: $APP_NAME
Version: $VERSION
Section: utils
Priority: optional
Architecture: $ARCH
Depends: awscli, jq, bc, gzip
Maintainer: TuNombre <tu@email.com>
Description: RainbowGen CLI - Generador de rainbow tables con subida a S3 y soporte paralelo
EOF

# Crear el paquete .deb
dpkg-deb --build $PKG_DIR

# Limpiar
mv ${PKG_DIR}.deb ${APP_NAME}_${VERSION}_${ARCH}.deb
rm -rf $PKG_DIR

echo "✅ Paquete creado: ${APP_NAME}_${VERSION}_${ARCH}.deb"
