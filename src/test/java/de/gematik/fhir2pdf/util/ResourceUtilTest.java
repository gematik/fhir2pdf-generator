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

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;

import java.net.URI;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.jar.JarEntry;
import java.util.jar.JarOutputStream;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

class ResourceUtilTest {

  @ParameterizedTest
  @ValueSource(
      strings = {
        "material/ttf/LiberationSans-Regular.ttf",
        "material/ttf/LiberationSans-Bold.ttf",
        "material/ttf/LiberationSansNarrow-Regular.ttf",
      })
  void loadTtf(String resource) {
    assertThat(ResourceUtil.read(resource)).isNotEmpty();
    assertThat(ResourceUtil.getUri(resource)).isNotNull();
  }

  @ParameterizedTest
  @ValueSource(strings = {"input/emp.xml"})
  void loadXml(String resource) {
    assertThat(ResourceUtil.read(resource)).isNotEmpty();
  }

  @ParameterizedTest
  @ValueSource(
      strings = {
        "material/stylesheet/xml-to-pdf.xsl",
        "material/stylesheet/fhir-json-to-xml.xsl",
      })
  void loadXsl(String resource) {
    assertThat(ResourceUtil.read(resource)).isNotEmpty();
  }

  @Test
  void nonExistingResourceThrows() {
    assertThat(ResourceUtil.read("non-existing-resource.txt")).isNull();
    assertThat(ResourceUtil.getUri("non-existing-resource.txt")).isNull();
  }

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
        "input/xml/file.xml"
      })
  void createNameFromInputJson(Path p) {
    assertThat(Util.createPdfName(p)).contains("file_").endsWith(".pdf");
  }

  @ParameterizedTest
  @ValueSource(
      strings = {
        "a/file.png",
        "C:/a/file.jpeg",
        "/a/file.aaaa",
        "a/b/c/file",
        "a/.wrongFormat",
        ""
      })
  void createNameFromInputThrows(Path p) {
    assertThatCode(() -> Util.createPdfName(p))
        .isInstanceOf(IllegalArgumentException.class)
        .hasMessageStartingWith("Unsupported extension:");
  }

  @Test
  void getAllInput() {
    assertThat(ResourceUtil.getAllInput())
        .containsExactlyInAnyOrder("input/emp.json", "input/emp.xml");
  }

  @Test
  void listJarContainsOnlyFilesDirectlyInInput(@TempDir Path temp) throws Exception {
    var jar = temp.resolve("test.jar");
    try (var out = new JarOutputStream(Files.newOutputStream(jar))) {
      for (var name :
          new String[] {
            "input/", "input/a.xml", "input/b.json", "input/sub/c.xml", "other/d.xml"
          }) {
        out.putNextEntry(new JarEntry(name));
        out.closeEntry();
      }
    }
    var directory = URI.create("jar:" + jar.toUri() + "!/input/").toURL();

    assertThat(ResourceUtil.list(directory))
        .containsExactlyInAnyOrder("input/a.xml", "input/b.json");
  }

  @Test
  void listDirectoryContainsOnlyRegularFiles(@TempDir Path temp) throws Exception {
    Files.createDirectory(temp.resolve("sub"));
    Files.writeString(temp.resolve("a.xml"), "<a/>");

    assertThat(ResourceUtil.list(temp.toUri().toURL())).containsExactly("input/a.xml");
  }

  @Test
  void listUnsupportedProtocolIsEmpty() throws Exception {
    assertThat(ResourceUtil.list(URI.create("http://localhost/input/").toURL())).isEmpty();
  }
}
