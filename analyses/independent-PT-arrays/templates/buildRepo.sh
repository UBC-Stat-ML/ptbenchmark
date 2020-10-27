#!/bin/bash


git clone https://github.com/${gitUser}/${gitRepoName}
cd ${gitRepoName}
git reset --hard ${codeRevision}
./gradlew installDist
mv build/install/`ls build/install/` ../code
mv data ../
echo Repo built