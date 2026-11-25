# Release Notes fhir2pdf-generator

## Release 1.1.0

* Fix: running the packaged JAR failed with `ClosedFileSystemException` when reading the bundled input files.
* Fix: decimal doses such as `0,75` are no longer split across two lines; the font is reduced instead.

## Release 1.0.0

* Initial release: renders a FHIR R4 medication plan (eMP) bundle (XML or JSON) as PDF/A-2b and validates it with
  veraPDF.
