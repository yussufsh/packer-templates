name 'travis_ci_connie'
maintainer 'Travis CI GmbH'
maintainer_email 'contact+travis-ci-connie-cookbook@travis-ci.org'
license 'MIT'
description 'Installs/Configures travis_ci_connie'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version '0.1.0'
source_url 'https://github.com/travis-ci/packer-templates'
issues_url 'https://github.com/travis-ci/packer-templates/issues'

depends 'apt'
depends 'clang'
depends 'nodejs'
depends 'postgresql'
depends 'sweeper'
depends 'sysctl'
depends 'travis_build_environment'
depends 'travis_docker'
depends 'travis_git'
depends 'travis_java'
depends 'travis_packer_templates'
depends 'travis_perlbrew'
depends 'travis_python'
depends 'travis_system_info'
