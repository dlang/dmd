#!/bin/env groovy

node {
    stage ("Load CI Scripts") {
        dir ("dlang/ci") {
            git "https://github.com/dlang-test/ci.git"
        }
    }

    load "dlang/ci/pipeline.groovy"
}
