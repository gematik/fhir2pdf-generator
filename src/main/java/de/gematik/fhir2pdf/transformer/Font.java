package de.gematik.fhir2pdf.transformer;

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

import de.gematik.fhir2pdf.util.ResourceUtil;
import java.nio.file.Path;
import lombok.Getter;

@Getter
enum Font {
  REGULAR("Liberation Sans", "normal", "material/ttf/LiberationSans-Regular.ttf"),
  BOLD("Liberation Sans", "bold", "material/ttf/LiberationSans-Bold.ttf"),
  NARROW("Liberation Sans Narrow", "normal", "material/ttf/LiberationSansNarrow-Regular.ttf"),
  NARROW_BOLD("Liberation Sans Narrow", "bold", "material/ttf/LiberationSansNarrow-Bold.ttf");

  private final String name;
  private final String weight;
  private final Path path;

  Font(String name, String weight, String filePath) {
    this.name = name;
    this.weight = weight;
    this.path = ResourceUtil.get(filePath);
  }

  String getXml() {
    return """
    <font embed-url="%s">
      <font-triplet name="%s" style="normal" weight="%s"/>
    </font>\
    """
        .formatted(path.toUri(), name, weight);
  }
}
