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
import java.net.URI;
import java.nio.file.FileSystem;
import java.nio.file.FileSystemAlreadyExistsException;
import java.nio.file.FileSystems;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Collection;
import java.util.Collections;
import java.util.Map;
import java.util.stream.Collectors;
import lombok.SneakyThrows;
import lombok.experimental.UtilityClass;

/** Finds files that are packaged inside the application. */
@UtilityClass
public class ResourceUtil {

  private static final String RESOURCE_INPUT = "input/";

  /**
   * Finds a file packaged inside the application.
   *
   * @param resourcePath the classpath-relative path, using {@code /}
   * @return the {@link Path}, or {@code null} if the resource does not exist
   */
  @SneakyThrows
  public Path get(String resourcePath) {
    var resource = ResourceUtil.class.getClassLoader().getResource(resourcePath);
    if (resource == null) {
      return null;
    }
    var uri = resource.toURI();
    return "jar".equals(uri.getScheme()) ? getFromJar(uri) : Path.of(uri);
  }

  /**
   * Finds all sample health records bundled with the application.
   *
   * @return the files in {@code input/} in no guaranteed order; empty if there are none
   */
  @SneakyThrows
  public Collection<Path> getAllInput() {
    var directory = get(RESOURCE_INPUT);
    if (directory == null || !Files.isDirectory(directory)) {
      return Collections.emptyList();
    }
    try (var inputResources = Files.list(directory)) {
      return inputResources.collect(Collectors.toSet());
    }
  }

  // The file system must stay open: the returned path is bound to it.
  @SuppressWarnings("java:S2095")
  private Path getFromJar(URI uri) throws IOException {
    var parts = uri.toString().split("!", 2);
    var jarUri = URI.create(parts[0]);
    FileSystem fileSystem;
    try (var fs = FileSystems.newFileSystem(jarUri, Map.of())) {
      fileSystem = fs;
    } catch (FileSystemAlreadyExistsException _) {
      fileSystem = FileSystems.getFileSystem(jarUri);
    }
    return fileSystem.getPath(parts[1]);
  }
}
