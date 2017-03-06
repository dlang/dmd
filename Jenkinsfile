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

node {
    dir('dlang/ci') {
        clone 'https://github.com/Dicebot/dlangci.git'
    }
    load 'dlang/ci/pipeline.groovy'
}
