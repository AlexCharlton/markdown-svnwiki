# markdown-svnwiki
Converts Markdown to the svnwiki syntax used on the [Chicken wiki](https://wiki.call-cc.org/edit-help). It uses [lowdown](http://wiki.call-cc.org/eggref/4/lowdown) to transform Markdown into SXML before transforming it into svnwiki with [sxml-transforms](http://wiki.call-cc.org/eggref/4/sxml-transforms). Much credit goes to those two libraries, particularly lowdown which heavily influenced the code in markdown-svnwiki.

markdown-svnwiki includes pre and post-processing phases for performing customizable transformations on the input and output. Some transformations, meant to make working with the Chicken wiki more convenient, are included by default. They are described in the section Special Syntax.

## Installation
This repository is a [Chicken Scheme](http://call-cc.org/) egg.

It is part of the [Chicken egg index](http://wiki.call-cc.org/chicken-projects/egg-index-4.html) and can be installed with `chicken-install markdown-svnwiki`.

## Requirements
* lowdown
* sxml-transforms
* miscmacros

## Documentation

    [procedure] (markdown->svnwiki input)

Convert the given `input` (may be a string or a port) into svnwiki, outputting to `current-output-port`.

    [parameter] pre-processing

An alist of functions that accept a string (the input to `markdown->svnwiki`) and should transform it in some way. By default contains one entry: `code-blocks`, for dealing with code blocks as described in Special Syntax.

    [parameter] post-processing
An alist of functions that accept a string (the pre-post-processed output from `markdown->svnwiki`) and should transform it in some way. By default contains: `code-blocks`, `procedure`, `macro`, `read`, `parameter`, `record`, `string`, `class`, `method`, `constant`, `setter`, `syntax`, and `type`, for dealing with code blocks and definition tags as described in Special Syntax.

    [parameter] toc

If true, inserts `[[toc:]]` after the first-level heading(s). Defaults to `#t`.

### Special syntax
markdown-svnwiki supports the syntax highlighted code blocks that [GitHub](help.github.com/articles/github-flavored-markdown#syntax-highlighting), [Pandoc](http://johnmacfarlane.net/pandoc/README.html#fenced-code-blocks) and perhaps others support. It converts these blocks into the `<enscript>` tags that highlight with the given language. It does this using a pre and post-processing step, both named `code-blocks`. These code blocks take the following form:

    ``` Scheme
    code ...
    ```

Becomes:

    <enscript highlight="scheme">
    code ...
    </enscript>

Additionally, markdown-svnwiki supports a special syntax for adding the [definition tags](https://wiki.call-cc.org/edit-help#extensions-for-chicken-documentation) supported by the Chicken wiki. Single-line verbatim code blocks that begin with exactly four spaces followed by `[definition-type]` are given a `<definition-type>` tag. Only the tags supported by the Chicken wiki are supported. For example:

        [procedure] (my-proc ...)

Becomes:

    <procedure>(my-proc ...)</procedure>

## Example
This example can be compiled to make a command line program that accepts one argument - a Markdown file - and outputs a svnwiki file into the same directory. It shows the addition of of a pre-processing step - one that removes the first section called "Installation" (fairly indiscriminately, it stops at the first `#`).

``` Scheme
(import chicken scheme irregex)
(use markdown-svnwiki)

(define file-name (cadr (argv)))
(define output-name (pathname-replace-extension file-name "svnwiki"))

(pre-processing
 (cons
  (cons 'remove-installation
        (lambda (s)
          (irregex-replace "## Installation[^#]*" s "")))
  (pre-processing)))

(call-with-output-file output-name
  (lambda (output)
    (call-with-input-file file-name
      (lambda (input)
        (current-output-port output)
        (markdown->svnwiki input)))))
```

## Version history
### Version 0.1.0
* Initial release

## Source repository
Source available on [GitHub](https://github.com/AlexCharlton/markdown-svnwiki).

Bug reports and patches welcome! Bugs can be reported via GitHub or to alex.n.charlton at gmail.

## Author
Alex Charlton

## License
BSD
