#!/bin/env groovy

def clone (repo_url, git_ref = "master") {
    checkout(
        poll: false,
        scm: [
            $class: 'GitSCM',
            branches: [[name: git_ref]],
            extensions: [[$class: 'CleanBeforeCheckout']],
            userRemoteConfigs: [[url: repo_url]]
        ]
    )
}

def pipeline
node {
    dir('dlang/ci') {
        clone 'https://github.com/dlang/ci.git', 'master'
    }
    pipeline = load 'dlang/ci/pipeline.groovy'
}
pipeline.runPipeline()
