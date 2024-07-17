#!/bin/bash

usage() {
    echo "Usage: $0 mode=<mode> [n=VALUE] [bx=VALUE] [by=VALUE] [tm=VALUE] [tn=VALUE] [tk=VALUE][opt_loop_unroll=VALUE] [opt_register=VALUE] [opt_branch=VALUE]"
    echo "  where <mode> must be one of 'naive', 'basic_shm', or 'tiling'."
}

if [ "$#" -lt 1 ]; then
    usage
    exit 1
fi

#default value
bx=16
by=16
tm=8
tn=8
tk=4
opt_loop_unroll=1
opt_register=1
opt_branch=1
n=1024
mode=""

for arg in "$@"; do
    key=$(echo $arg | cut -f1 -d=)
    value=$(echo $arg | cut -f2 -d=)

    case $key in
        mode)
            if [[ "$value" == "naive" || "$value" == "basic_shm" || "$value" == "tiling" ]]; then
                mode=$value
            else
                echo "Error: mode must be one of 'naive', 'basic_shm', or 'tiling'."
                usage
                exit 1
            fi
            ;;
        bx)
            bx=$value
            ;;
        by)
            by=$value
            ;;
        tm)
            tm=$value
            ;;
        tn)
            tn=$value
            ;;
        tk)
            tk=$value
            ;;
        opt_loop_unroll)
            opt_loop_unroll=$value
            ;;
        opt_register)
            opt_register=$value
            ;;
        opt_branch)
            opt_branch=$value
            ;;
        n)
            n=$value
            ;;
        *)
            echo "Warning: Ignoring unrecognized option '$key'."
            ;;
    esac
done

if [ -z "$mode" ]; then
    echo "Error: The 'mode' parameter is required."
    usage
    exit 1
fi

echo "Running in mode: $mode"
echo "Basic options - n: $n, bx: $bx, by: $by, tm: $tm tn: $tn tk:$tk"
echo "Optimization options - opt_loop_unroll: $opt_loop_unroll, opt_register: $opt_register, opt_branch: $opt_branch"

sudo nvidia-smi -ac 5001,1590
make -C build_T4 mode=$mode bx=$bx by=$by tm=$tm tn=$tn tk=$tk opt_loop_unroll=$opt_loop_unroll opt_register=$opt_register opt_branch=$opt_branch #> /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "Make succeeded, running ./mmpy with n=$n"
    ./mmpy -n $n
else
    echo "Make failed, not running ./mmpy"
    exit 1
fi