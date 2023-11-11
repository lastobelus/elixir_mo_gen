echo $1
if [ "$1" = "-dbg" ]; then
  VERSION=`cat mix.exs | grep '  @version '| sed -e 's/.*@version "\(.*\)"/\1/'`
  TIMESTAMP=`date +%Y-%m-%d-%H%M`

  BASESRCDIR=${BASESRCDIR:-"$HOME/.local-mix-archives"}
  mkdir -p $BASESRCDIR

  NAME="elixir_mo_gen-$VERSION-$TIMESTAMP"
  SRCDIR="$BASESRCDIR/$NAME"
  ARCHIVE="$SRCDIR/$NAME.ez"
  
  echo "Installing locally with snapshot of source in $SRCDIR"
  rsync -r\
        --include=".tool-versions"\
        --exclude="_build"\
        --exclude="/.*"\
        --exclude="*.ez"\
        --exclude="test"\
        --exclude="tmp"\
        --exclude="todos"\
        --exclude="*.sh"\
        . $SRCDIR
        cd $SRCDIR
  MIX_ENV=prod mix do archive.build -o "$ARCHIVE", archive.install $ARCHIVE
else
  echo "Installing locally"
  MIX_ENV=prod mix do archive.build, archive.install
fi

