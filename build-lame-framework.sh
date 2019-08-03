#!/bin/sh
##By Majid Hatami
#mjhatamy @ gmail.com

LAME_FILE=lame-3.100.tar.gz
LAME_DIR=lame-3.100
MIN_IOS=10.0

rm -rf $LAME_DIR;

if ! [ -f $LAME_FILE ];then
	echo "downloading $LAME_FILE ..."
	curl -o $LAME_FILE https://managedway.dl.sourceforge.net/project/lame/lame/3.100/lame-3.100.tar.gz
	if [ $? != 0 ];then
		echo "downloading $LAME_FILE error ...";
		exit -1;
	else
		echo "downloading $LAME_FILE done ...";
	fi
fi

tar xf $LAME_FILE;

if [ $? != 0 ];then
	echo "extract $LAME_FILE error ...";
	rm -rf $LAME_FILE;
	rm -rf $LAME_DIR;
	exit -1;
fi
#ln -s $LAME_DIR lame;

CONFIGURE_FLAGS="--disable-shared --disable-frontend"

ARCHS="arm64 armv7s x86_64 i386 armv7"

# directories
#SOURCE="lame"
SOURCE=$LAME_DIR
FAT="fat"

SCRATCH=".scratch-lame"
# must be an absolute path
THIN=`pwd`/".thin-lame"

COMPILE="y"
LIPO="y"
FRAMEWORK="y"

if [ "$*" ]
then
	if [ "$*" = "lipo" ]
	then
		# skip compile
		COMPILE=
	else
		ARCHS="$*"
		if [ $# -eq 1 ]
		then
			# skip lipo
			LIPO=
		fi
	fi
fi

if [ "$COMPILE" ]
then
	CWD=`pwd`
	for ARCH in $ARCHS
	do
		echo "building $ARCH..."
		mkdir -p "$SCRATCH/$ARCH"
		cd "$SCRATCH/$ARCH"

		if [ "$ARCH" = "i386" -o "$ARCH" = "x86_64" ]
		then
		    PLATFORM="iPhoneSimulator"
		    if [ "$ARCH" = "x86_64" ]
		    then
		    	SIMULATOR="-mios-simulator-version-min=$MIN_IOS"
                        HOST=x86_64-apple-darwin
		    else
                SIMULATOR="-mios-simulator-version-min=$MIN_IOS"
                        HOST=i386-apple-darwin
		    fi
		else
		    PLATFORM="iPhoneOS"
		    SIMULATOR="-miphoneos-version-min=$MIN_IOS"
                    HOST=arm-apple-darwin
		fi

		XCRUN_SDK=`echo $PLATFORM | tr '[:upper:]' '[:lower:]'`
		CC="xcrun -sdk $XCRUN_SDK clang -arch $ARCH"
		#AS="$CWD/$SOURCE/extras/gas-preprocessor.pl $CC"
		CFLAGS="-arch $ARCH $SIMULATOR -fembed-bitcode"
		CXXFLAGS="$CFLAGS"
		LDFLAGS="$CFLAGS"

		CC=$CC $CWD/$SOURCE/configure \
		    $CONFIGURE_FLAGS \
                    --host=$HOST \
		    --prefix="$THIN/$ARCH" \
                    CC="$CC" CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS"

		make -j3 install
		cd $CWD
	done
fi

if [ "$LIPO" ]
then
	echo "building fat binaries..."
	mkdir -p $FAT/lib
	set - $ARCHS
	CWD=`pwd`
	cd $THIN/$1/lib
	for LIB in *.a
	do
		cd $CWD
		lipo -create `find $THIN -name $LIB` -output $FAT/lib/$LIB
	done

	cd $CWD
	cp -rf $THIN/$1/include $FAT
fi

if [ "$FRAMEWORK" ]
then
	rm -rf lame.framework
	echo "building lame.framework..."
	mkdir -p lame.framework/Headers/
	cp -rf $FAT/include/lame/* lame.framework/Headers/
	cp -f $FAT/lib/libmp3lame.a lame.framework/lame
fi

echo "FAT Directory::> $fat"
#   clean tmp directories
rm -rf $SOURCE  $SCRATCH $THIN #$FAT
