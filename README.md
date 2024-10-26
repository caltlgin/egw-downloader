# EGW Downloader

A command-line tool to download and convert books from the Ellen G. White Estate website into high-quality PDFs. For books that don't have official PDF downloads available, this script assembles them from the web content while preserving proper formatting and adding metadata.

## Features

- Downloads and converts books that don't have official PDF versions
- Downloads official PDFs when available
- Adds book cover images (generates placeholder covers if none available)
- Includes proper page breaks and table of contents
- Adds comprehensive metadata to generated PDFs
- Handles duplicate pages automatically
- Polite to the server with built-in rate limiting
- Supports books with special characters in titles

## Prerequisites

The following dependencies must be installed:

- `curl` - For downloading web content
- `exiftool` - For adding PDF metadata
- `wkhtmltopdf` - For HTML to PDF conversion
- `xidel` - For HTML parsing

### Important Notes:
- Download wkhtmltopdf with patched Qt from https://wkhtmltopdf.org
- Download xidel from https://github.com/benibela/xidel

## Usage

```bash
egw-downloader <book_id> [output_directory]
```

### Parameters:
- `book_id`: Required. The ID number from the book's URL
- `output_directory`: Optional. Where to save the generated PDF (defaults to ~/Downloads/egw-downloader)

### How to Find Book ID
Get the Book ID from the mobile URL of the book. For example:
```
https://m.egwwritings.org/en/book/133/info
                                  ^^^
                              Book ID is 133
```

## Output

The script generates a PDF file with:
- Book cover (or generated placeholder)
- Table of contents
- Properly formatted content
- Page numbers
- Complete metadata (title, author, description)

The output filename follows the format: `<book_code> - <title>.pdf`

## Pre-downloaded Books

To avoid unnecessary load on the Ellen G. White servers, many books have been pre-downloaded and archived. You can find them at: [Archive.org - Ellen G. White Collection](https://archive.org/details/@caltlgin-stsodaat?and[]=subject%3A%22ellen+g.+white%22)

## Examples

Download a specific book to the default location:
```bash
egw-downloader 133
```

Download to a custom directory:
```bash
egw-downloader 133 ~/Documents/egw-books
```
