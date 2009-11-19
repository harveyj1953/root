#!/bin/sh

# This script is almost identical to /usr/bin/gstack.
# It is used by TUnixSystem::StackTrace() on Linux and MacOS X.

tempname=`basename $0 .sh`

OUTFILE=`mktemp -q /tmp/${tempname}.XXXXXX`
if test $? -ne 0; then
   OUTFILE=/dev/stdout
fi

if [ `uname -s` = "Darwin" ]; then

   if test $# -ne 2; then
      echo "Usage: ${tempname} <executable> <process-id>" 1>&2
      exit 1
   fi

   if test ! -x $1; then
      echo "${tempname}: process $1 not found." 1>&2
      exit 1
   fi

   TMPFILE=`mktemp -q /tmp/${tempname}.XXXXXX`
   if test $? -ne 0; then
      echo "${tempname}: can't create temp file, exiting..." 1>&2
      exit 1
   fi

   backtrace="thread apply all bt"

   echo $backtrace > $TMPFILE

   GDB=${GDB:-gdb}

   # Run GDB, strip out unwanted noise.
   $GDB -q -batch -n -x $TMPFILE $1 $2 2>&1 |
   /usr/bin/sed -n \
    -e 's/^(gdb) //' \
    -e '/^#/p' \
    -e 's/\(^Thread.*\)/@\1/p' | tr "@" "\n" > $OUTFILE

   rm -f $TMPFILE

else

   if test $# -ne 1; then
      echo "Usage: ${tempname} <process-id>" 1>&2
      exit 1
   fi

   if test ! -r /proc/$1; then
      echo "${tempname}: process $1 not found." 1>&2
      exit 1
   fi

   # GDB doesn't allow "thread apply all bt" when the process isn't
   # threaded; need to peek at the process to determine if that or the
   # simpler "bt" should be used.
   # The leading spaces are needed for have_eval_command's replacement.

   backtrace="bt"
   if test -d /proc/$1/task ; then
      # Newer kernel; has a task/ directory.
      if test `ls /proc/$1/task | wc -l` -gt 1 2>/dev/null ; then
         backtrace="thread apply all bt"
      fi
   elif test -f /proc/$1/maps ; then
      # Older kernel; go by it loading libpthread.
      if grep -e libpthread /proc/$1/maps > /dev/null 2>&1 ; then
         backtrace="thread apply all bt"
      fi
   fi

   GDB=${GDB:-gdb}

   # Run GDB, strip out unwanted noise.
   have_eval_command=`gdb --help 2>&1 |grep eval-command`
   if ! test "x$have_eval_command" = "x"; then
      $GDB --batch --eval-command="$backtrace" /proc/$1/exe $1 2>&1 |
      /bin/sed -n \
         -e 's/^(gdb) //' \
         -e '/^#/p' \
         -e '/^   /p' \
         -e 's/\(^Thread.*\)/@\1/p' | tr '@' '\n' > $OUTFILE
   else
      $GDB -q -n /proc/$1/exe $1 <<EOF 2>&1 |
   $backtrace
EOF
      /bin/sed -n \
         -e 's/^(gdb) //' \
         -e '/^#/p' \
         -e '/^   /p' \
         -e 's/\(^Thread.*\)/@\1/p' | tr '@' '\n' > $OUTFILE
   fi
fi

# Analyze the stack.
# The recommendations are based on the following assumptions:
#   * More often than not, the crash is caused by user code.
#   * The crash can be caused by the user's interpreted code,
#     in which case sighandler() is called from CINT (G__...)
#   * The crash can be called by the user's library code,
#     in which case sighandler() is called from non-CINT and
#     it's worth dumping the stack frames.
#   * The user doesn't call CINT directly, so whenever we reach
#     a stack frame with "G__" we can stop.
#   * The crash is caused by only one thread, the one which
#     invokes sighandler()

if ! test "x$OUTFILE" = "x/dev/stdout"; then
   frames=""
   wantthread=""
   skip=""
   ininterp=""
   signal=""
   while IFS= read line; do
      case $line in
         *'<signal handler called>'* )
            # this frame doesn't exist
            continue
            ;;
         Thread* )
            if test "x$wantthread" = "xyes"; then
               break
            fi
            skip=""
            frames=""
            ;;
         '#'* )
            skip=""
            ;;
      esac
      if test "x${skip}" = "x"; then
         tag=`echo $line|sed 's,^.* in ,,'`
         if test "x$ininterp" = "xcheck next"; then
            ininterp="check this"
         fi
         case $tag in
            SigHandler* )
               signal=`echo $line | sed 's/^.*\(kSig[^)]*\).*$/\1/'`
               ;;
            sighandler* )
               wantthread="yes"
               ininterp="check next"
               frames=""
               ;;
            G__* | Cint::G__* )
               if test "x$ininterp" = "xcheck this"; then
                  ininterp="yes"
                  break
               elif test "x$ininterp" = "xno"; then
                  break
               fi
               skip="yes"
               ;;
            *::ProcessLine* | TRint::HandleTermInput* )
               # frames to ignore (upper end)
               if test "x$ininterp" = "xcheck this"; then
                  ininterp="no"
                  break
               fi
               if test "x$wantthread" = "xyes"; then
                  break;
               fi
               skip="yes"
               ;;
            * )
               if test "x${skip}" = "x"; then
                  if test "x$frames" = "x"; then
                     frames="$line"
                  else
                     frames="$frames
$line"
                  fi
               fi
               if test "x$ininterp" = "xcheck this"; then
                  ininterp="no"
               fi
               ;;
         esac
      fi
   done < $OUTFILE

   # Only print the informative text if we actually have a crash
   # but not when TSystem::Stacktrace() was called.
   if ! test "x$signal" = "x"; then
      echo ""
      echo ""
      echo ""
      echo "==========================================================="
      echo "There was a crash ($signal)."
      echo "This is the entire stack trace of all threads:"
      echo "==========================================================="
   fi
   cat $OUTFILE
   if ! test "x$signal" = "x"; then
      echo "==========================================================="
      if test "x$ininterp" = "xyes"; then
         echo ""
         echo ""
         echo "The crash is most likely caused by a problem in your script."
         echo 'Try to compile it (.L myscript.C+g) and fix any errors.'
         echo 'If that does not help then please submit a bug report'
         echo 'at http://root.cern.ch/bugs. Please post the ENTIRE stack'
         echo 'trace from above as an attachment in addition to anything else'
         echo 'that might help us fixing this issue.'
      elif ! test "x$frames" = "x"; then
         echo ""
         echo ""
         echo "The crash is most likely caused by a problem in your compiled code."
         echo "The lines below might give you a hint. If they do not help you then"
         echo "please submit a bug report at http://root.cern.ch/bugs. Please"
         echo "post the ENTIRE stack trace from above as an attachment in"
         echo "addition to anything else that might help us fixing this issue."
         echo "==========================================================="
         echo "$frames"
         echo "==========================================================="
      fi
      echo ""
      echo ""
   fi

   rm -f $OUTFILE
fi
