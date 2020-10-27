#!/bin/bash


cd ${snapshotPath}
./gradlew installDist
cd -
ln -s ${snapshotPath}/build/install/`ls ${snapshotPath}/build/install/` code
ln -s ${snapshotPath}/data data
