#!/bin/sh

_SUBSTRUCTION () {
    echo | awk "{printf \"%.3f\", $1-$2}"
}

_MESSAGE_FORMATTER () {
    awk '{printf "| %-28s | %9s |\n",$1" "$2,$3}'
}

LOG_TABLE () {
    time_begin=$(date +%s -d "$(awk '/.*DEBUG Hexo version/{print $1}' build.log)")
    time_process_start=$(date +%s.%3N -d "$(awk '/.*INFO  Start processing/{print $1}' build.log)")
    time_render_start=$(date +%s.%3N -d "$(awk '/.*INFO  Files loaded in/{print $1}' build.log)")
    time_render_finish=$(date +%s.%3N -d "$(awk '/.*INFO.*generated in /{print $1}' build.log)")
    time_database_saved=$(date +%s.%3N -d "$(awk '/.*DEBUG Database saved/{print $1}' build.log)")

    memory_usage=$(awk '/.*Maximum resident set size/{print $6}' build.log)

    echo "Load Plugin/Scripts/Database $(_SUBSTRUCTION $time_process_start $time_begin)s" | _MESSAGE_FORMATTER
    echo "Process Source $(_SUBSTRUCTION $time_render_start $time_process_start)s" | _MESSAGE_FORMATTER
    echo "Render Files $(_SUBSTRUCTION $time_render_finish $time_render_start)s" | _MESSAGE_FORMATTER
    echo "Save Database $(_SUBSTRUCTION $time_database_saved $time_render_finish)s" | _MESSAGE_FORMATTER
    echo "Total time $(_SUBSTRUCTION $time_database_saved $time_begin)s" | _MESSAGE_FORMATTER
    echo "Memory Usage(RSS) $(echo | awk "{printf \"%.3f\", $memory_usage/1024}")MB" | _MESSAGE_FORMATTER

    total_time=$(_SUBSTRUCTION $time_database_saved $time_begin | xargs -0 printf "%.0f")
    line_number=$(wc -l build.log | cut -d" " -f1)

    if [ "$1" != "HOT" ]; then
        if [ "$total_time" -lt 10 ] || [ "$line_number" -lt 300 ]; then
            echo "--------------------------------------------"
            echo -e '\033[41;37m !! Build failed !! \033[0m'
            head -n 400 build.log
            exit 1
        fi
    fi

    # if [ "$total_time" -gt 40 ]; then
    #     echo "--------------------------------------------"
    #     echo -e '\033[41;37m !! Performance regression detected !! \033[0m'
    #     exit 1
    # fi
}

echo "============== Hexo Benchmark =============="
LOG_DATA_DIR=benchmark-data/data-$TRAVIS_BRANCH
LOG_DATA_FILE=$TRAVIS_BRANCH-$TRAVIS_BUILD_NUMBER-node-${TRAVIS_NODE_VERSION}-`date +%Y%m%d%H%M%S`

echo "- Set up dummy Hexo site"
mkdir -p dummy && cd dummy && rm -rf benchmark-test-site
git clone -b benchmark-test-site-300 https://github.com/dailyrandomphoto/hexo-benchmark.git benchmark-test-site --depth=1 --quiet
cd benchmark-test-site

# echo "- Import 900 posts"
# cp -a source/_posts/hexo-many-posts source/_posts/hexo-many-posts-2
# cp -a source/_posts/hexo-many-posts source/_posts/hexo-many-posts-3

echo "- Replace package.json and _config.yml"
cp -rf ../../overwrite/* ./

echo "- npm install"
npm install --silent

echo "- Prepare benchmark data"
git clone https://github.com/dailyrandomphoto/hexo-benchmark-data.git benchmark-data --depth=1 --quiet
mkdir -p $LOG_DATA_DIR

echo "- Start test run"

echo "------------- Cold processing --------------" | tee -a $LOG_DATA_DIR/$LOG_DATA_FILE
{ /usr/bin/time -v npm run g > build.log 2>&1 ; } 2> build.log
LOG_TABLE | tee -a $LOG_DATA_DIR/$LOG_DATA_FILE

echo "-------------- Hot processing --------------" | tee -a $LOG_DATA_DIR/$LOG_DATA_FILE
{ /usr/bin/time -v npm run g > build.log 2>&1 ; } 2> build.log
LOG_TABLE "HOT" | tee -a $LOG_DATA_DIR/$LOG_DATA_FILE

echo "--------- Another Cold processing ----------" | tee -a $LOG_DATA_DIR/$LOG_DATA_FILE
npm run c > build.log
{ /usr/bin/time -v npm run g > build.log 2>&1 ; } 2> build.log
LOG_TABLE | tee -a $LOG_DATA_DIR/$LOG_DATA_FILE

echo "--------------------------------------------" | tee -a $LOG_DATA_DIR/$LOG_DATA_FILE
rm -rf build.log

cd benchmark-data
../../../push.sh
