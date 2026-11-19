package de.gematik.fhir2pdf.util;

/*-
 * #%L
 * fhir2pdf-generator
 * %%
 * Copyright (C) 2026 gematik GmbH
 * %%
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * *******
 *
 * For additional notes and disclaimer from gematik and in case of changes
 * by gematik, find details in the "Readme" file.
 * #L%
 */

import java.nio.file.Files;
import java.nio.file.Path;
import lombok.SneakyThrows;
import lombok.experimental.UtilityClass;
import org.verapdf.pdfa.flavours.PDFAFlavour;

/** Small helpers shared across the application. */
@UtilityClass
public class Util {

  /** Name of the system property that sets the folder where the PDFs are saved. */
  public final String OUTPUT_DIRECTORY_PROPERTY = "fhir2pdf.output.dir";

  private final String DEFAULT_OUTPUT_DIRECTORY = "target/generated-pdf";

  /**
   * Gives a readable name for a PDF archiving format.
   *
   * @param flavour the flavour, may be {@code null}
   * @return e.g. {@code PDF/A-2b}, or {@code null} if the flavour is {@code null}
   */
  public String asString(PDFAFlavour flavour) {
    return flavour == null
        ? null
        : "%s-%s".formatted(flavour.getPart().getFamily().getFamily(), flavour);
  }

  /**
   * Returns the name of a file, without its folder.
   *
   * @param p the path, may be {@code null}
   * @return the file name, or {@code null} if the path is {@code null}
   */
  public String getFilename(Path p) {
    return p == null ? null : p.getFileName().toString();
  }

  /**
   * Prepares the save location of a PDF and creates the output folder if needed.
   *
   * @param fileName the PDF file name, must end with {@code .pdf}
   * @return the path of the PDF inside the output directory
   * @throws IllegalArgumentException if the file name does not end with {@code .pdf}
   */
  @SneakyThrows
  public Path createPdf(String fileName) {
    Extension.PDF.check(fileName);
    var directory =
        Path.of(System.getProperty(OUTPUT_DIRECTORY_PROPERTY, DEFAULT_OUTPUT_DIRECTORY));
    Files.createDirectories(directory);
    return directory.resolve(fileName);
  }

  /**
   * Works out the PDF name for a health record file.
   *
   * @param input the XML or JSON input file
   * @return the file name with dots replaced by underscores plus {@code .pdf}, e.g. {@code
   *     emp_xml.pdf}
   * @throws IllegalArgumentException if the input is {@code null} or not an XML or JSON file
   */
  public String createPdfName(Path input) {
    if (input == null) {
      throw new IllegalArgumentException("Input path must not be null");
    }
    var _ = Extension.fromPath(input);
    return getFilename(input).replace(".", "_") + ".pdf";
  }
}
