# ASX Watcher

This project contains simple mAIcro scripts that fetch ASX stock information from the Market Index website and return either raw text or markdown reports.

Script path in project storage: `scripts/asx_watcher`

## Overview

The scripts use the X4m pipeline operation `FETCH_URL` to read public stock pages such as:

- `https://www.marketindex.com.au/asx/dro`
- `https://www.marketindex.com.au/asx/tlx`

Some scripts then format the fetched content with `TO_MARKDOWN`.

## Scripts

- `01.multi_stock.gql`
  - Fetches multiple ASX symbols concurrently.
  - Returns raw, unformatted text.
  - Current symbols: `dro`, `tlx`.

- `02.single_stock_md.gql`
  - Fetches one ASX symbol.
  - Converts the result to markdown with `TO_MARKDOWN`.
  - Current symbol: `dro`.

- `03.multi_stock_md.gql`
  - Fetches multiple ASX symbols.
  - Converts each result to markdown with `TO_MARKDOWN`.
  - Current symbols: `dro`, `tlx`.

## Outputs

Depending on the script you run, output will be:

- Raw text content from the Market Index page.
- Markdown-formatted report content.

## How To Use

1. Open the project in mAIcro.
2. Go to the Scripts area.
3. Open scripts under `scripts/asx_watcher`.
4. Run one of the scripts based on the output you want:
   - Raw multi-stock text: `01.multi_stock.gql`
   - Single-stock markdown report: `02.single_stock_md.gql`
   - Multi-stock markdown reports: `03.multi_stock_md.gql`

## Notes

- These are lightweight example scripts for data fetch and formatting.
- They do not create database tables or mutate database data.
- To track a different ASX code, update the Market Index URL in the `FETCH_URL` step.
