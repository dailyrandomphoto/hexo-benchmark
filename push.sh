#!/bin/sh

setup_git() {
  git config user.email "dailyrandomphoto@gmail.com"
  git config user.name "dailyrandomphoto"
  git remote add origin-pages https://${GITHUB_TOKEN}@github.com/dailyrandomphoto/hexo-benchmark-data.git > /dev/null 2>&1
}

commit_files() {
  git add --all
  git commit --message "Benchmark on Travis: #$TRAVIS_BUILD_NUMBER for $TRAVIS_BRANCH on node-$TRAVIS_NODE_VERSION"
}

upload_files() {
  git pull -r -f origin master
  git push --quiet --set-upstream origin-pages master
  if [ $? -gt 0 ]; then
    echo "push again"
    upload_files
  fi
}

setup_git
commit_files
upload_files
