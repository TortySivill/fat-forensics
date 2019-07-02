# Makefile simplifying repetitive dev commands

# Set the default shell to /bin/bash (from /bin/sh) to support source command
#SHELL := /bin/bash

$(mkdir -p temp)

ifndef TRAVIS_PYTHON_VERSION
	PYTHON_VERSION := $(shell python -V | grep -Eo '\d+.\d+.\d+')
else
	PYTHON_VERSION := $(TRAVIS_PYTHON_VERSION)
endif

ifndef FATF_TEST_MATPLOTLIB
	MATPLOTLIB_VERSION := $(shell sed -n 's/matplotlib\(.*\)/\1/p' \
		requirements-aux.txt)
else
	MATPLOTLIB_VERSION := ==$(FATF_TEST_MATPLOTLIB)
endif

ifndef FATF_TEST_LIME
	LIME_VERSION := $(shell sed -n 's/lime\(.*\)/\1/p' requirements-aux.txt)
else
	LIME_VERSION := ==$(FATF_TEST_LIME)
endif

# Get environment variables if _envar.sh exists
-include _envar.sh

.PHONY: all install install-sans-dep install-dev dependencies \
	dependencies-dev doc-html doc-html-coverage doc-linkcheck doc-coverage \
	test-doc test-notebooks test code-coverage test-with-code-coverage \
	deploy-code-coverage linting-pylint linting-flake8 linting-yapf check-types \
	build readme-gen readme-preview validate-travis validate-sphinx-conf \
	find-flags

all: \
	test-with-code-coverage \
	test-notebooks \
	test-doc \
	\
	doc-html \
	doc-linkcheck \
	doc-coverage \
	\
	check-types \
	linting-pylint \
	linting-flake8 \
	linting-yapf

install:
	pip install .

install-sans-dep:
	pip install --no-deps .

install-dev:
	pip install --no-deps -e .

install-matplotlib:
	pip install "matplotlib$(MATPLOTLIB_VERSION)"

install-lime:
	pip install "lime$(LIME_VERSION)"

dependencies:
	pip install -r requirements.txt

dependencies-dev:
ifdef FATF_TEST_NUMPY
ifeq ($(FATF_TEST_NUMPY),latest)
	pip install --upgrade numpy
else
	pip install numpy==$(FATF_TEST_NUMPY)
endif
endif
ifdef FATF_TEST_SCIPY
ifeq ($(FATF_TEST_SCIPY),latest)
#	pip install --only-binary=scipy --upgrade scipy
	pip install --upgrade scipy
else
#	pip install --only-binary=scipy scipy==$(FATF_TEST_SCIPY)
	pip install scipy==$(FATF_TEST_SCIPY)
endif
endif
	pip install -r requirements.txt
	pip install -r requirements-dev.txt

#doc: Makefile
#	$(MAKE) -C doc $(filter-out $@,$(MAKECMDGOALS))
#	exit 0

# Catch-all unmatched targets -> do nothing (silently)
# This is needed for doc target as any argument for that command will be just
# another target for make. It makes it dangerous as `make doc all` will
# additionally execute all target for this make as well.
#%:
#	@:

# Check doc: references (-n -- nit-picky mode -- generates warnings for all
# missing references) and linkage (-W changes all warnings into errors meaning
# unlinked sources will cause the build to fail.)
doc-html:
	mkdir -p doc/_build
	mkdir -p doc/_static
	PYTHONPATH=./ sphinx-build \
		-M html doc doc/_build \
		-nW \
		-w doc/_build/nit-picky-html.txt
	cat doc/_build/nit-picky-html.txt
#	$(MAKE) -C doc html

doc-linkcheck:
	mkdir -p doc/_build/linkcheck
	PYTHONPATH=./ sphinx-build -M linkcheck doc doc/_build
	cat doc/_build/linkcheck/output.txt
#	$(MAKE) -C doc linkcheck

doc-coverage:
	mkdir -p doc/_build/coverage
	PYTHONPATH=./ sphinx-build -M coverage doc doc/_build
	cat doc/_build/coverage/python.txt
#	$(MAKE) -C doc html -b coverage  # Build html with docstring coverage report
#	$(MAKE) -C doc coverage

doc-doctest:
	sphinx-build -M doctest doc doc/_build
#	$(MAKE) -C doc doctest

doc-clean:
	sphinx-build -M clean doc doc/_build

# Do doctests only: https://github.com/pytest-dev/pytest/issues/4726
# Given that this is work-in-progress feature use docs-doctest instead
# (`-k 'not test_ and not Test'` is used as a hack -- no doctests in functions
# starting with `test_` and classes starting with `Test` will be found.)
test-doc:
	PYTHONPATH=./ PYTEST_IN_PROGRESS='true' pytest \
		--doctest-glob='*.txt' \
		--doctest-glob='*.rst' \
		--doctest-modules \
		--ignore=doc/_build/ \
		--ignore=doc/sphinx_gallery_auto/ \
		-k 'not test_ and not Test' \
		doc/ \
		fatf/

test-notebooks:
	PYTHONPATH=./ PYTEST_IN_PROGRESS='true' pytest \
		--nbval \
		examples/

test:
	FATF_SEED=42 PYTHONPATH=./ PYTEST_IN_PROGRESS='true' pytest \
		--junit-xml=temp/pytest_$(PYTHON_VERSION).xml \
		fatf/

code-coverage:
	FATF_SEED=42 PYTHONPATH=./ PYTEST_IN_PROGRESS='true' pytest \
		--cov-report=term-missing \
		--cov-report=xml:temp/coverage_$(PYTHON_VERSION).xml \
		--cov=fatf \
		fatf/

test-with-code-coverage:
	FATF_SEED=42 PYTHONPATH=./ PYTEST_IN_PROGRESS='true' pytest \
		--junit-xml=temp/pytest_$(PYTHON_VERSION).xml \
		--cov-report=term-missing \
		--cov-report=xml:temp/coverage_$(PYTHON_VERSION).xml \
		--cov=fatf \
		fatf/

deploy-code-coverage:
# @ before the command suppresses printing it out, hence hides the token
ifeq ($(TRAVIS_PULL_REQUEST),'false')
ifndef CODECOV_TOKEN
	@echo 'CODECOV_TOKEN environment variable is NOT set'
	$(error CODECOV_TOKEN is undefined)
else
	@echo 'codecov -t $$CODECOV_TOKEN -f temp/coverage_$(PYTHON_VERSION).xml'
#	@codecov -t $(CODECOV_TOKEN) -f temp/coverage_$(PYTHON_VERSION).xml
endif
else
	@echo 'Code coverage can only be submitted from a branch of the upstream repo'
	$(error TRAVIS_PULL_REQUEST is undefined)
endif

linting-pylint:
# pylint may misbehave when the package under testing is installed as editable!
	pylint --rcfile=.pylintrc fatf/
	pylint --rcfile=.pylintrc --disable=invalid-name examples/

linting-flake8:
	flake8 --config=.flake8 fatf/
	flake8 --config=.flake8 examples/

linting-yapf:
	yapf --style .style.yapf -p -r -d -vv fatf/
	yapf --style .style.yapf -p -r -d -vv examples/

# TODO(kacper): Consider `pytype` when it allows to ignore with glob patterns
check-types:
	mypy --config-file=.mypy.ini fatf/

build:
	python3 setup.py sdist bdist_wheel

readme-gen:
	pandoc -t html README.rst -o temp/README.html

readme-preview:
	restview README.rst

validate-travis:
	travis lint .travis.yml

validate-sphinx-conf:
	pylint --rcfile=.pylintrc -d invalid-name doc/conf.py
	flake8 --config=.flake8 doc/conf.py
	yapf --style .style.yapf -p -r -d -vv doc/conf.py

find-flags:
	ag "# yapf" fatf || true
	ag "# pylint" fatf || true
	ag "# type" fatf || true
	ag "# pragma" fatf || true
	ag "TODO" . || true
