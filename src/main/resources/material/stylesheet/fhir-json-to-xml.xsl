<?xml version="1.0" encoding="UTF-8"?>
<!--
  #%L
  fhir2pdf-generator
  %%
  Copyright (C) 2026 gematik GmbH
  %%
  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at
  
      http://www.apache.org/licenses/LICENSE-2.0
  
  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
  
  *******
  
  For additional notes and disclaimer from gematik and in case of changes
  by gematik, find details in the "Readme" file.
  #L%
  -->

<!--
  FHIR R4 JSON -> FHIR R4 XML (HL7 JSON/XML representation rules).

  Parameter
    json      content of the JSON document
  The source document is ignored (use any dummy document).

  Rules implemented
    - resourceType becomes the element name; a nested resource (Bundle.entry.resource, contained) is wrapped
      in the element of its property
    - primitives become <name value="..."/>; "_name" (id, extension) is merged into the same element
    - arrays become repeated elements; primitive arrays are paired index by index with "_name" arrays
    - "id" of a non-resource element and "url" of an extension become attributes
    - Narrative.div (XHTML string) is parsed into real XHTML
    - numbers keep the lexical form of the JSON input (decimal precision is not lost)
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:j="http://www.w3.org/2005/xpath-functions"
                version="3.0"
                xmlns="http://hl7.org/fhir"
                xpath-default-namespace="http://www.w3.org/2005/xpath-functions"
                exclude-result-prefixes="xs j">

    <xsl:output method="xml" encoding="UTF-8" indent="no"/>

    <xsl:param name="json" as="xs:string" required="yes"/>

    <xsl:template match="/">
        <xsl:apply-templates select="json-to-xml($json)/map" mode="resource"/>
    </xsl:template>

    <xsl:template match="map" mode="resource">
        <xsl:element name="{string[@key = 'resourceType']}" namespace="http://hl7.org/fhir">
            <xsl:apply-templates select="." mode="content">
                <xsl:with-param name="is-resource" select="true()"/>
            </xsl:apply-templates>
        </xsl:element>
    </xsl:template>

    <!-- attributes first, then one element per property -->
    <xsl:template match="map" mode="content">
        <xsl:param name="is-resource" as="xs:boolean" select="false()"/>
        <xsl:param name="parent" as="xs:string" select="''"/>
        <xsl:variable name="m" select="."/>
        <xsl:variable name="keys" select="distinct-values(*/@key ! replace(., '^_', ''))[. ne 'resourceType']"/>

        <xsl:if test="not($is-resource) and $m/string[@key = 'id']">
            <xsl:attribute name="id" select="$m/string[@key = 'id']"/>
        </xsl:if>
        <xsl:if test="$parent = ('extension', 'modifierExtension') and $m/string[@key = 'url']">
            <xsl:attribute name="url" select="$m/string[@key = 'url']"/>
        </xsl:if>

        <xsl:for-each select="$keys">
            <xsl:variable name="k" select="."/>
            <xsl:if test="not((not($is-resource) and $k = 'id')
                              or ($parent = ('extension', 'modifierExtension') and $k = 'url'))">
                <xsl:variable name="v" select="$m/*[@key = $k]"/>
                <xsl:variable name="p" select="$m/*[@key = concat('_', $k)]"/>
                <xsl:choose>
                    <xsl:when test="$v/self::array or $p/self::array">
                        <xsl:for-each select="1 to max((count($v/*), count($p/*)))">
                            <xsl:call-template name="property">
                                <xsl:with-param name="name" select="$k"/>
                                <xsl:with-param name="v-in" select="$v/*[current()]"/>
                                <xsl:with-param name="p-in" select="$p/*[current()]"/>
                                <xsl:with-param name="parent" select="$parent"/>
                            </xsl:call-template>
                        </xsl:for-each>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:call-template name="property">
                            <xsl:with-param name="name" select="$k"/>
                            <xsl:with-param name="v-in" select="$v"/>
                            <xsl:with-param name="p-in" select="$p"/>
                            <xsl:with-param name="parent" select="$parent"/>
                        </xsl:call-template>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:if>
        </xsl:for-each>
    </xsl:template>

    <xsl:template name="property">
        <xsl:param name="name" as="xs:string"/>
        <xsl:param name="v-in" as="element()?"/>
        <xsl:param name="p-in" as="element()?"/>
        <xsl:param name="parent" as="xs:string"/>
        <xsl:variable name="v" select="$v-in[not(self::null)]"/>
        <xsl:variable name="p" select="$p-in[not(self::null)]"/>
        <xsl:choose>
            <xsl:when test="empty($v) and empty($p)"/>
            <xsl:when test="$v/self::map[string[@key = 'resourceType']]">
                <xsl:element name="{$name}" namespace="http://hl7.org/fhir">
                    <xsl:apply-templates select="$v" mode="resource"/>
                </xsl:element>
            </xsl:when>
            <xsl:when test="$v/self::map">
                <xsl:element name="{$name}" namespace="http://hl7.org/fhir">
                    <xsl:apply-templates select="$v" mode="content">
                        <xsl:with-param name="parent" select="$name"/>
                    </xsl:apply-templates>
                </xsl:element>
            </xsl:when>
            <xsl:when test="$name = 'div' and $parent = 'text' and $v/self::string">
                <xsl:sequence select="parse-xml-fragment($v)"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:element name="{$name}" namespace="http://hl7.org/fhir">
                    <xsl:if test="exists($v)">
                        <xsl:attribute name="value" select="string($v)"/>
                    </xsl:if>
                    <xsl:if test="$p/self::map">
                        <xsl:apply-templates select="$p" mode="content">
                            <xsl:with-param name="parent" select="$name"/>
                        </xsl:apply-templates>
                    </xsl:if>
                </xsl:element>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

</xsl:stylesheet>
