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

import java.nio.file.Path;
import lombok.Getter;

/** The kinds of files the application works with. */
@Getter
public enum Extension {
  /** Layout template. */
  XSL("xsl"),
  /** Health record in XML format. */
  XML("xml"),
  /** Health record in JSON format. */
  JSON("json"),
  /** PDF document. */
  PDF("pdf");

  /** The file extension without the leading dot, e.g. {@code xml}. */
  private final String value;

  Extension(String value) {
    this.value = value;
  }

  /**
   * Works out the kind of a file from its name.
   *
   * @param input the file path
   * @return the matching {@link Extension}
   * @throws IllegalArgumentException if the extension is not supported
   */
  public static Extension fromPath(Path input) {
    var filename = Util.getFilename(input);
    for (Extension extension : values()) {
      if (filename.toLowerCase().trim().endsWith("." + extension.value)) {
        return extension;
      }
    }
    throw new IllegalArgumentException("Unsupported extension: %s".formatted(filename));
  }

  /**
   * Makes sure a file name is of this kind.
   *
   * @param filename the file name to check
   * @throws IllegalArgumentException if the extension does not match
   */
  public void check(String filename) {
    if (filename.toLowerCase().trim().endsWith("." + value)) {
      return;
    }
    throw new IllegalArgumentException(
        "File %s does not have the expected extension: %s".formatted(filename, value));
  }
}
