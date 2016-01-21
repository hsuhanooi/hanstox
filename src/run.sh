#!/bin/bash


ruby src/scrape_morningstar.rb $1
ruby src/fetch_data.rb $1
