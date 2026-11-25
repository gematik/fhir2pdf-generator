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

import java.io.IOException;
import java.net.JarURLConnection;
import java.net.URI;
import java.net.URISyntaxException;
import java.net.URL;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Collection;
import java.util.Set;
import java.util.jar.JarEntry;
import java.util.stream.Collectors;
import lombok.SneakyThrows;
import lombok.experimental.UtilityClass;

/** Finds files that are packaged inside the application, on disk as well as inside a JAR. */
@UtilityClass
public class ResourceUtil {

  private static final String RESOURCE_INPUT = "input/";

  /**
   * Finds the location of a file packaged inside the application.
   *
   * @param resourcePath the classpath-relative path, using {@code /}
   * @return the {@link URI}, or {@code null} if the resource does not exist
   */
  @SneakyThrows
  public URI getUri(String resourcePath) {
    var resource = ResourceUtil.class.getClassLoader().getResource(resourcePath);
    return resource == null ? null : resource.toURI();
  }

  /**
   * Reads a file packaged inside the application.
   *
   * @param resourcePath the classpath-relative path, using {@code /}
   * @return the content, or {@code null} if the resource does not exist
   */
  @SneakyThrows
  public byte[] read(String resourcePath) {
    try (var stream = ResourceUtil.class.getClassLoader().getResourceAsStream(resourcePath)) {
      return stream == null ? null : stream.readAllBytes();
    }
  }

  /**
   * Finds all sample health records bundled with the application.
   *
   * @return the classpath-relative names of the files in {@code input/}, in no guaranteed order;
   *     empty if there are none
   */
  @SneakyThrows
  public Collection<String> getAllInput() {
    var directory = ResourceUtil.class.getClassLoader().getResource(RESOURCE_INPUT);
    if (directory == null) {
      return Set.of();
    }
    return list(directory);
  }

  Collection<String> list(URL directory) throws IOException, URISyntaxException {
    return switch (directory.getProtocol()) {
      case "jar" -> listJar(directory);
      case "file" -> listDirectory(Path.of(directory.toURI()));
      default -> Set.of();
    };
  }

  Set<String> listJar(URL directory) throws IOException {
    var connection = (JarURLConnection) directory.openConnection();
    // A private JarFile that is safe to close, because it is not shared through the JVM cache.
    connection.setUseCaches(false);
    try (var jar = connection.getJarFile()) {
      return jar.stream()
          .filter(entry -> !entry.isDirectory())
          .map(JarEntry::getName)
          .filter(name -> name.startsWith(RESOURCE_INPUT))
          .filter(name -> name.indexOf('/', RESOURCE_INPUT.length()) < 0)
          .collect(Collectors.toSet());
    }
  }

  Set<String> listDirectory(Path directory) throws IOException {
    try (var files = Files.list(directory)) {
      return files
          .filter(Files::isRegularFile)
          .map(file -> RESOURCE_INPUT + file.getFileName())
          .collect(Collectors.toSet());
    }
  }
}
