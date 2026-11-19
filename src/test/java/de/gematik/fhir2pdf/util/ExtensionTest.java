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

import static org.assertj.core.api.Assertions.assertThatCode;

import java.nio.file.Path;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

class ExtensionTest {

  @ParameterizedTest
  @ValueSource(
      strings = {
        "a/file.json",
        "C:/a/file.json",
        "a/b/c/file.json",
        "in.put/js.on/file.json",
        "a/file.xml",
        "/a/file.xml",
        "a/b/c/file.xml",
        "input/xml/file.xml",
        "C:\\Users\\max.mustermann\\docs\\file.xml"
      })
  void fromPath(String path) {
    assertThatCode(() -> Extension.fromPath(Path.of(path))).doesNotThrowAnyException();
  }

  @Test
  void check() {
    assertThatCode(() -> Extension.JSON.check("file.json")).doesNotThrowAnyException();
    assertThatCode(() -> Extension.XML.check("file.xml")).doesNotThrowAnyException();
    assertThatCode(() -> Extension.PDF.check("file.pdf")).doesNotThrowAnyException();
  }

  @Test
  void checkThrows() {
    assertThatCode(() -> Extension.JSON.check("file.xml"))
        .isInstanceOf(IllegalArgumentException.class);
    assertThatCode(() -> Extension.XML.check("file.json"))
        .isInstanceOf(IllegalArgumentException.class);
    assertThatCode(() -> Extension.PDF.check("file.xml"))
        .isInstanceOf(IllegalArgumentException.class);
  }
}
