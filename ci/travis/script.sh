#!/bin/bash -ex

if [ "$TRAVIS_OS_NAME" = 'osx' ]; then
    export PYTHONPATH=$PYTHONPATH:/usr/local/lib/python2.7/site-packages
fi

function install_cuda_linux()
{
    if [[ "$1" != "xenial" ]]; then
        wget -q https://developer.nvidia.com/compute/cuda/8.0/Prod2/local_installers/cuda-repo-ubuntu1404-8-0-local-ga2_8.0.61-1_amd64-deb -O cuda-repo-ubuntu1404-8-0-local-ga2_8.0.61-1_amd64.deb
        sudo dpkg -i cuda-repo-ubuntu1404-8-0-local-ga2_8.0.61-1_amd64.deb
    else
        echo "Installing for Xenial CUDA 9.0!"
        sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys F60F4B3D7FA2AF80
        wget -q https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1604/x86_64/cuda-repo-ubuntu1604_9.0.176-1_amd64.deb -O cuda-repo-ubuntu1604_9.0.176-1_amd64.deb
        sudo dpkg -i cuda-repo-ubuntu1604_9.0.176-1_amd64.deb
    fi
 
    sudo apt-get update -qq -o=Dpkg::Use-Pty=0
    sudo apt-get install -qq -o=Dpkg::Use-Pty=0 cuda    
    ls -oah /usr/local
}


if [ "${CB_BUILD_AGENT}" == 'clang-linux-x86_64-release-cuda' ]; then
    install_cuda_linux xenial;
    ./ya make --no-emit-status --stat -T -r catboost/app -DCUDA_ROOT=/usr/local/cuda-9.2 -DNO_DEBUGINFO;
    cp $(readlink -f catboost/app/catboost) catboost-cuda-linux;
    python ci/webdav_upload.py catboost-cuda-linux
fi

if [ "${CB_BUILD_AGENT}" == 'python2-linux-x86_64-release' ]; then
     install_cuda_linux;
     cd catboost/python-package;
     python2 ./mk_wheel.py --no-emit-status -T -DCUDA_ROOT=/usr/local/cuda-8.0 ;
     python ../../ci/webdav_upload.py *.whl
fi

if [ "${CB_BUILD_AGENT}" == 'python34-linux-x86_64-release' ]; then
     ls /home/travis/virtualenv
     PYTHON_DIR="/home/travis/virtualenv/python$(python3 --version | cut -d' ' -f2)"
     ln -s $PYTHON_DIR/bin/python-config $PYTHON_DIR/bin/python3-config;
     install_cuda_linux;
     cd catboost/python-package;
     python3 ./mk_wheel.py --no-emit-status -T -DCUDA_ROOT=/usr/local/cuda-8.0 -DPYTHON_CONFIG=$PYTHON_DIR/bin/python3-config;
     python ../../ci/webdav_upload.py *.whl
fi

if [ "${CB_BUILD_AGENT}" == 'python35-linux-x86_64-release' ]; then
     PYTHON_DIR="/home/travis/virtualenv/python$(python3 --version | cut -d' ' -f2)"
     ln -s $PYTHON_DIR/bin/python-config $PYTHON_DIR/bin/python3-config;
     install_cuda_linux;
     cd catboost/python-package;
     python3 ./mk_wheel.py --no-emit-status -T -DCUDA_ROOT=/usr/local/cuda-8.0 -DPYTHON_CONFIG=$PYTHON_DIR/bin/python3-config;
     python ../../ci/webdav_upload.py *.whl
fi

if [ "${CB_BUILD_AGENT}" == 'python36-linux-x86_64-release' ]; then
     PYTHON_DIR="/home/travis/virtualenv/python$(python3 --version | cut -d' ' -f2)"
     ln -s $PYTHON_DIR/bin/python-config $PYTHON_DIR/bin/python3-config;
     install_cuda_linux;
     cd catboost/python-package;
     python3 ./mk_wheel.py --no-emit-status -T -DCUDA_ROOT=/usr/local/cuda-8.0 -DPYTHON_CONFIG=$PYTHON_DIR/bin/python3-config;
     python ../../ci/webdav_upload.py *.whl
fi

if [ "${CB_BUILD_AGENT}" == 'clang-darwin-x86_64-release' ]; then
    ./ya make --no-emit-status --stat -T -r catboost/app;
    cp $(readlink catboost/app/catboost) catboost-darwin;
    python ci/webdav_upload.py catboost-darwin
fi

if [ "${CB_BUILD_AGENT}" == 'R-clang-darwin-x86_64-release' ] || [ "${CB_BUILD_AGENT}" == 'R-clang-linux-x86_64-release' ]; then
    cd catboost/R-package

    mkdir catboost

    cp DESCRIPTION catboost
    cp NAMESPACE catboost
    cp README.md catboost

    cp -r R catboost

    cp -r inst catboost
    cp -r man catboost
    cp -r tests catboost

    ../../ya make -r -T src

    mkdir catboost/inst/libs
    cp $(readlink src/libcatboostr.so) catboost/inst/libs

    tar -cvzf catboost-R-$(uname).tgz catboost
    python ../../ci/webdav_upload.py catboost-R-*.tgz
fi

