#!/bin/env groovy

node {
    sh 'env > env.txt'
    readFile('env.txt').split("\r?\n").each {
        println it
    }
    stage ("Load CI Scripts") {
        dir ("dlang/ci") {
            git "https://github.com/dlang-test/ci.git"
        }
    }

    load "dlang/ci/pipeline.groovy"
}
