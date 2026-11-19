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
  eMP-Offline-Stylesheet: FHIR-Bundle (XML) -> XSL-FO (-> PDF mit Apache FOP)

  Quelle: Render API "Medikationsplan abrufen (eMP)", IG ePA Medication Service v1.4.0-ballot.1,
          Kap. 13.2.1.4 (Schematischer Aufbau) und 13.2.2 (Offline-Rendering).
  Prozessor: XSLT 3.0, Saxon-HE (>= 11.6; getestet mit 11.6 und 13.1), keine Erweiterungsfunktionen.
  Ausgabe: XSL-FO 1.1 für Apache FOP (getestet mit 2.11).

  Die betroffenen Stellen sind im Code mit ANNAHME, VORLÄUFIG, VORGABE bzw. ABWEICHUNG markiert.

  Parameter (genau einer): creationDateTime (xs:string, Pflicht), z. B. "04.11.2026 10:13"; wird unverändert ausgegeben.

  Aufrufbeispiel (Windows-Pfade anpassen):
    java -cp saxon-he.jar net.sf.saxon.Transform -s:emp.xml -xsl:xml-to-pdf.xsl -o:emp.fo "creationDateTime=04.11.2026 10:13"
    fop -c fop.xconf -fo emp.fo -pdf emp.pdf

  Benötigte fop.xconf-Schriftkonfiguration (Einbettung und Pfade liegen beim Primärsystemhersteller):
    <fop version="1.0"><renderers><renderer mime="application/pdf"><fonts>
      <font embed-url="LiberationSans-Regular.ttf"> <font-triplet name="Liberation Sans" style="normal" weight="normal"/></font>
      <font embed-url="LiberationSans-Bold.ttf">    <font-triplet name="Liberation Sans" style="normal" weight="bold"/></font>
      <font embed-url="LiberationSansNarrow-Regular.ttf"> <font-triplet name="Liberation Sans Narrow" style="normal" weight="normal"/></font>
    </fonts></renderer></renderers></fop>
  Die Zeichenbreiten unten stammen aus genau diesen Fontdateien (Liberation Sans Regular, Bold und Liberation Sans Narrow Regular).
  PDF/A ist für das Offline-Rendering nicht erforderlich (IG-MED10996EDH). Optional kann in der fop.xconf zusätzlich
  <pdf-a-mode>PDF/A-2b</pdf-a-mode> gesetzt werden (mit diesem Stylesheet getestet, veraPDF-konform).

  Zeilenumbruch: Das Stylesheet berechnet Textbreiten und Umbrüche selbst (Zeichenbreitentabelle in xsl:map,
  Breite = floor(Advance * 1000 / unitsPerEm), wie in FOP; ohne Kerning). Jede berechnete Zeile wird als eigener
  Block ohne automatischen Umbruch ausgegeben.
-->
<xsl:stylesheet version="3.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:fo="http://www.w3.org/1999/XSL/Format"
                xmlns:map="http://www.w3.org/2005/xpath-functions/map"
                xmlns:array="http://www.w3.org/2005/xpath-functions/array"
                xmlns:f="urn:gematik:emp:offline"
                xpath-default-namespace="http://hl7.org/fhir"
                exclude-result-prefixes="xs map array f">

  <xsl:output method="xml" encoding="UTF-8" indent="no"/>

  <xsl:param name="creationDateTime" as="xs:string" required="yes"/>

  <!-- ===== Konstanten (Längen in mm, Schriftgrößen in pt) ===== -->
  <xsl:variable name="PT-MM" as="xs:double" select="25.4 div 72"/>
  <xsl:variable name="ROW" as="xs:double" select="8.75"/>
  <xsl:variable name="PAD" as="xs:double" select="1.0"/>
  <xsl:variable name="PAD-BLOCK" as="xs:double" select="1.5"/>
  <xsl:variable name="LH" as="xs:double" select="1.17"/>
  <xsl:variable name="COLS" as="xs:double+" select="(40, 44, 18, 20, 8, 8, 8, 8, 20, 62, 44)"/>
  <xsl:variable name="TOTAL-W" as="xs:double" select="sum($COLS)"/>
  <xsl:variable name="HEAD-H" as="xs:double" select="22.5"/>
  <xsl:variable name="GAP-H" as="xs:double" select="3"/>
  <xsl:variable name="FOOT-H" as="xs:double" select="10"/>
  <xsl:variable name="BW-SOLID" as="xs:double" select="0.5 * $PT-MM"/>
  <!-- ANNAHME: Strichlinien 0,53 pt. FOP erzeugt Strich = 6 x Stärke, Lücke = 3 x Stärke und streckt das Muster auf die
       Linienlänge (ganzzahlige Wiederholung). Bei 0,53 pt und Linienlängen ab 24,8 pt liegen Strich 3,2-3,9 pt und
       Lücke 1,6-1,9 pt innerhalb der Toleranz (3 pt ±1, 2 pt ±0,5). -->
  <xsl:variable name="BW-DASH" as="xs:double" select="0.53 * $PT-MM"/>
  <xsl:variable name="BW-THICK" as="xs:double" select="3 * $PT-MM"/>
  <xsl:variable name="SOLID" as="xs:string" select="'0.5pt solid black'"/>
  <xsl:variable name="DASH" as="xs:string" select="'0.53pt dashed black'"/>
  <xsl:variable name="THICK" as="xs:string" select="'3pt solid black'"/>
  <xsl:variable name="ZW" as="xs:double" select="$TOTAL-W - 2 * $BW-THICK - 2 * $PAD"/>

  <xsl:variable name="U-SORT" select="'https://gematik.de/fhir/epa/StructureDefinition/emp-sort-priority-extension'"/>
  <xsl:variable name="U-NOTE" select="'https://gematik.de/fhir/epa-medication/StructureDefinition/patient-note-extension'"/>
  <xsl:variable name="U-REASON" select="'https://gematik.de/fhir/epa-medication/StructureDefinition/reason-patient-instruction-extension'"/>
  <xsl:variable name="U-RENDERED" select="'http://hl7.org/fhir/5.0/StructureDefinition/extension-MedicationRequest.renderedDosageInstruction'"/>
  <xsl:variable name="U-AMOUNT" select="'https://gematik.de/fhir/epa-medication/StructureDefinition/medication-ingredient-amount-extension'"/>
  <xsl:variable name="SYS-KVNR" select="'http://fhir.de/sid/gkv/kvid-10'"/>
  <xsl:variable name="SYS-IFA" select="'https://fhir.ifaffm.de/CodeSystem/IFA_DARREICHUNGSFORM'"/>
  <xsl:variable name="SYS-KBV" select="'https://fhir.kbv.de/CodeSystem/KBV_CS_SFHIR_KBV_DARREICHUNGSFORM'"/>
  <xsl:variable name="WHEN-CODES" as="xs:string+" select="('MORN', 'NOON', 'EVE', 'NIGHT')"/>

    <!-- ===== Zeichenbreiten (1/1000 em) aus den Fontdateien LiberationSans-Regular.ttf, LiberationSans-Bold.ttf, LiberationSansNarrow-Regular.ttf (hmtx, floor wie FOP) ===== -->
  <xsl:variable name="CP" as="xs:integer+"
                select="(32 to 126, 160 to 383, 8210 to 8213, 8216 to 8222, 8224 to 8226, 8230, 8240, 8364, 8482, 8722, 913 to 929, 931 to 969)"/>
  <xsl:variable name="W-REGULAR" as="xs:integer+"
                select="(277,277,354,556,556,889,666,190,333,333,389,583,277,333,277,277,556,556,556,556,556,556,556,556,556,556,277,277,583,583,583,556,
1015,666,666,722,722,666,610,777,722,277,500,666,556,833,722,777,666,777,722,666,610,722,666,943,666,666,610,277,277,277,469,556,
333,556,556,500,556,556,277,556,556,222,222,500,222,833,556,556,556,556,333,500,277,556,500,722,500,500,500,333,259,333,583,277,
333,556,556,556,556,259,556,333,736,370,556,583,333,736,552,399,548,333,333,333,576,537,277,333,333,365,556,833,833,833,610,666,
666,666,666,666,666,1000,722,666,666,666,666,277,277,277,277,722,722,777,777,777,777,777,583,777,722,722,722,722,666,666,610,556,
556,556,556,556,556,889,500,556,556,556,556,277,277,277,277,556,556,556,556,556,556,556,548,610,556,556,556,556,500,556,500,666,
556,666,556,666,556,722,500,722,500,722,500,722,500,722,614,722,556,666,556,666,556,666,556,666,556,666,556,777,556,777,556,777,
556,777,556,722,556,722,556,277,277,277,277,277,277,277,222,277,277,734,443,500,222,666,500,500,556,222,556,222,556,291,556,333,
556,222,722,556,722,556,722,556,604,723,556,777,556,777,556,777,556,1000,943,722,333,722,333,722,333,666,500,666,500,666,500,666,
500,610,277,610,375,610,277,722,556,722,556,722,556,722,556,722,556,722,556,943,722,666,500,666,610,500,610,500,610,500,222,333,
556,1000,1000,222,222,222,222,333,333,333,556,556,350,1000,1000,556,1000,583,666,666,550,667,666,610,722,777,277,666,667,833,722,649,
777,722,666,618,610,666,797,666,835,747,277,666,578,445,556,222,546,578,575,500,556,445,440,556,556,222,500,500,576,500,447,556,
689,568,481,617,395,546,648,524,712,780)"/>
  <xsl:variable name="W-BOLD" as="xs:integer+"
                select="(277,333,474,556,556,889,722,237,333,333,389,583,277,333,277,277,556,556,556,556,556,556,556,556,556,556,333,333,583,583,583,610,
975,722,722,722,722,666,610,777,722,277,556,722,610,833,722,777,666,777,722,666,610,722,666,943,666,666,610,333,277,333,583,556,
333,556,610,556,610,556,333,610,610,277,277,556,277,889,610,610,610,610,389,556,333,610,556,777,556,556,500,389,279,389,583,277,
333,556,556,556,556,279,556,333,736,370,556,583,333,736,552,399,548,333,333,333,576,556,277,333,333,365,556,833,833,833,610,722,
722,722,722,722,722,1000,722,666,666,666,666,277,277,277,277,722,722,777,777,777,777,777,583,777,722,722,722,722,666,666,610,556,
556,556,556,556,556,889,556,556,556,556,556,277,277,277,277,610,610,610,610,610,610,610,548,610,610,610,610,610,556,610,556,722,
556,722,556,722,556,722,556,722,556,722,556,722,556,722,718,722,610,666,556,666,556,666,556,666,556,666,556,777,610,777,610,777,
610,777,610,722,610,722,610,277,277,277,277,277,277,277,277,277,277,784,556,556,277,722,556,556,610,277,610,277,610,385,610,479,
610,277,722,610,722,610,722,610,708,723,610,777,610,777,610,777,610,1000,943,722,389,722,389,722,389,666,556,666,556,666,556,666,
556,610,333,610,479,610,333,722,610,722,610,722,610,722,610,722,610,722,610,943,777,666,556,666,610,500,610,500,610,500,277,333,
556,1000,1000,277,277,277,277,500,500,500,556,556,350,1000,1000,556,1000,583,722,722,601,718,666,610,722,777,277,722,666,833,722,643,
777,722,666,600,610,666,820,666,809,801,277,666,614,451,610,277,582,614,610,556,606,474,460,610,540,277,557,556,611,556,445,610,
765,618,520,684,446,582,715,575,753,844)"/>
    <!-- Liberation Sans Narrow: nur ASCII 32 bis 126 (verwendet für die 8-pt-Kopfzeilentexte) -->
  <xsl:variable name="W-NARROW" as="xs:integer+"
                select="(228,228,291,456,456,729,546,157,272,272,318,479,228,272,228,228,456,456,456,456,456,456,456,456,456,456,228,228,479,479,479,456,
832,546,546,591,591,546,500,638,591,228,410,546,456,683,591,638,546,638,591,546,500,591,546,773,546,546,500,228,228,228,384,456,
272,456,456,410,456,456,228,456,456,182,182,410,182,683,456,456,456,456,272,410,228,456,410,591,410,410,410,273,212,273,479)"/>
  <xsl:variable name="M-REGULAR" as="map(xs:integer, xs:integer)"
                select="map:merge(for $i in 1 to count($CP) return map{ $CP[$i] : $W-REGULAR[$i] })"/>
  <xsl:variable name="M-BOLD" as="map(xs:integer, xs:integer)"
                select="map:merge(for $i in 1 to count($CP) return map{ $CP[$i] : $W-BOLD[$i] })"/>
  <xsl:variable name="M-NARROW" as="map(xs:integer, xs:integer)"
                select="map:merge(for $i in 1 to count($W-NARROW) return map{ 31 + $i : $W-NARROW[$i] })"/>

  <xsl:key name="med-by-id" match="/Bundle/entry/resource/Medication" use="id/@value"/>

  <xsl:variable name="patient" select="(/Bundle/entry/resource/Patient)[1]"/>

  <!-- IG-MED18735RJF-02: alle aktiven MedicationRequests des Bundes; Sortierung global (IG-MED61434W6C-02): sortPriority, authoredOn, id -->
  <xsl:variable name="items" as="element()*">
    <xsl:perform-sort select="/Bundle/entry/resource/MedicationRequest[status/@value = 'active']">
      <xsl:sort select="if (exists(f:sort-priority(.))) then 0 else 1" data-type="number"/>
      <xsl:sort select="(f:sort-priority(.), 0)[1]" data-type="number"/>
      <xsl:sort select="f:sort-datetime(string(authoredOn/@value))"/>
      <xsl:sort select="string(id/@value)" collation="http://www.w3.org/2005/xpath-functions/collation/codepoint"/>
    </xsl:perform-sort>
  </xsl:variable>

  <!-- ===== Hilfsfunktionen: Formatierung ===== -->
  <xsl:function name="f:mm" as="xs:string">
    <xsl:param name="v" as="xs:double"/>
    <xsl:sequence select="concat(format-number($v, '0.####'), 'mm')"/>
  </xsl:function>

  <xsl:function name="f:pt" as="xs:string">
    <xsl:param name="v" as="xs:double"/>
    <xsl:sequence select="concat(format-number($v, '0.###'), 'pt')"/>
  </xsl:function>

  <!-- VORGABE: Dezimaltrenner Komma; in der Spezifikation nicht geregelt -->
  <xsl:function name="f:num" as="xs:string">
    <xsl:param name="s" as="xs:string*"/>
    <xsl:sequence select="translate(string-join($s, ''), '.', ',')"/>
  </xsl:function>

  <xsl:function name="f:birth" as="xs:string">
    <xsl:param name="s" as="xs:string"/>
    <xsl:sequence select="if (matches($s, '^\d{4}-\d{2}-\d{2}$'))
                          then concat(substring($s, 9, 2), '.', substring($s, 6, 2), '.', substring($s, 1, 4))
                          else $s"/>
  </xsl:function>

  <!-- Anwendungszeitraum (IG-MED66689BZJ-01): dateTime mit Zeitzone nach Europe/Berlin; reines Datum ohne Uhrzeit -->
  <xsl:function name="f:bound" as="xs:string">
    <xsl:param name="s" as="xs:string"/>
    <xsl:variable name="pic" select="'[D01].[M01].[Y0001] [H01]:[m01]'"/>
    <xsl:choose>
      <xsl:when test="matches($s, '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})$')">
        <xsl:sequence select="concat(format-dateTime(xs:dateTime($s), $pic, 'en', (), 'Europe/Berlin'), ' Uhr')"/>
      </xsl:when>
      <!-- ANNAHME: ohne angegebene Zeitzone keine Umrechnung -->
      <xsl:when test="matches($s, '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?$')">
        <xsl:sequence select="concat(format-dateTime(xs:dateTime($s), $pic, 'en', (), ()), ' Uhr')"/>
      </xsl:when>
      <xsl:when test="matches($s, '^\d{4}-\d{2}-\d{2}$')">
        <xsl:sequence select="f:birth($s)"/>
      </xsl:when>
      <!-- ANNAHME: unvollständige Datumsangaben unverändert -->
      <xsl:otherwise><xsl:sequence select="$s"/></xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <!-- ===== Sortierschlüssel ===== -->
  <xsl:function name="f:sort-priority" as="xs:decimal?">
    <xsl:param name="mr" as="element()"/>
    <xsl:variable name="v" select="($mr/extension[@url = $U-SORT]/valueDecimal/@value)[1]"/>
    <xsl:sequence select="if (exists($v)) then xs:decimal($v) else ()"/>
  </xsl:function>

  <!-- ANNAHME: fehlendes authoredOn sortiert zuletzt; ohne Zeitzone gilt UTC; Teildaten werden mit dem frühesten Zeitpunkt aufgefüllt -->
  <xsl:function name="f:sort-datetime" as="xs:dateTime">
    <xsl:param name="s" as="xs:string"/>
    <xsl:variable name="utc" select="xs:dayTimeDuration('PT0S')"/>
    <xsl:choose>
      <xsl:when test="matches($s, '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})$')">
        <xsl:sequence select="adjust-dateTime-to-timezone(xs:dateTime($s), $utc)"/>
      </xsl:when>
      <xsl:when test="matches($s, '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?$')">
        <xsl:sequence select="xs:dateTime(concat($s, 'Z'))"/>
      </xsl:when>
      <xsl:when test="matches($s, '^\d{4}-\d{2}-\d{2}$')"><xsl:sequence select="xs:dateTime(concat($s, 'T00:00:00Z'))"/></xsl:when>
      <xsl:when test="matches($s, '^\d{4}-\d{2}$')"><xsl:sequence select="xs:dateTime(concat($s, '-01T00:00:00Z'))"/></xsl:when>
      <xsl:when test="matches($s, '^\d{4}$')"><xsl:sequence select="xs:dateTime(concat($s, '-01-01T00:00:00Z'))"/></xsl:when>
      <xsl:otherwise><xsl:sequence select="xs:dateTime('9999-12-31T23:59:59Z')"/></xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <!-- ===== Textbreite und Zeilenumbruch (IG-MED20994Z5N-01) ===== -->
  <!-- ANNAHME: Zeichen ohne Eintrag in der Breitentabelle werden mit 1000 gemessen -->
  <xsl:function name="f:cp-width" as="xs:integer">
    <xsl:param name="cp" as="xs:integer"/>
    <xsl:param name="font" as="xs:string"/>
    <xsl:variable name="m" select="if ($font = 'bold') then $M-BOLD else if ($font = 'narrow') then $M-NARROW else $M-REGULAR"/>
    <xsl:sequence select="($m($cp), 1000)[1]"/>
  </xsl:function>

  <!-- Textbreite in mm -->
  <xsl:function name="f:tw" as="xs:double">
    <xsl:param name="s" as="xs:string"/>
    <xsl:param name="font" as="xs:string"/>
    <xsl:param name="pt" as="xs:double"/>
    <xsl:sequence select="sum(for $c in string-to-codepoints($s) return f:cp-width($c, $font)) * $pt * $PT-MM div 1000"/>
  </xsl:function>

  <!-- Wörter; Wörter, die mit Satzzeichen (außer öffnenden) beginnen, bleiben beim vorigen Wort (keine Satzzeichen am Zeilenanfang) -->
  <xsl:function name="f:units" as="xs:string*">
    <xsl:param name="text" as="xs:string"/>
    <xsl:iterate select="tokenize(normalize-space($text), ' ')[. ne '']">
      <xsl:param name="acc" as="xs:string*" select="()"/>
      <xsl:on-completion select="$acc"/>
      <xsl:next-iteration>
        <xsl:with-param name="acc"
                        select="if (exists($acc) and matches(., '^[\p{P}-[\p{Ps}\p{Pi}]]'))
                                then (remove($acc, count($acc)), concat($acc[last()], ' ', .))
                                else ($acc, .)"/>
      </xsl:next-iteration>
    </xsl:iterate>
  </xsl:function>

  <!-- ANNAHME: ein Wort, das allein nicht in die Zeile passt, wird zeichenweise umbrochen (keine Silbentrennung) -->
  <xsl:function name="f:chop" as="xs:string*">
    <xsl:param name="word" as="xs:string"/>
    <xsl:param name="font" as="xs:string"/>
    <xsl:param name="pt" as="xs:double"/>
    <xsl:param name="avail" as="xs:double"/>
    <xsl:iterate select="string-to-codepoints($word)">
      <xsl:param name="done" as="xs:string*" select="()"/>
      <xsl:param name="cur" as="xs:string" select="''"/>
      <xsl:param name="w" as="xs:double" select="0"/>
      <xsl:on-completion select="($done, $cur)"/>
      <xsl:variable name="ch" select="codepoints-to-string(.)"/>
      <xsl:variable name="cw" select="f:tw($ch, $font, $pt)"/>
      <xsl:choose>
        <xsl:when test="$cur ne '' and $w + $cw gt $avail">
          <xsl:next-iteration>
            <xsl:with-param name="done" select="($done, $cur)"/>
            <xsl:with-param name="cur" select="$ch"/>
            <xsl:with-param name="w" select="$cw"/>
          </xsl:next-iteration>
        </xsl:when>
        <xsl:otherwise>
          <xsl:next-iteration>
            <xsl:with-param name="done" select="$done"/>
            <xsl:with-param name="cur" select="concat($cur, $ch)"/>
            <xsl:with-param name="w" select="$w + $cw"/>
          </xsl:next-iteration>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:iterate>
  </xsl:function>

  <!-- Greedy-Umbruch an Leerzeichen; liefert die Zeilen -->
  <xsl:function name="f:wrap" as="xs:string*">
    <xsl:param name="text" as="xs:string"/>
    <xsl:param name="font" as="xs:string"/>
    <xsl:param name="pt" as="xs:double"/>
    <xsl:param name="avail" as="xs:double"/>
    <xsl:variable name="sp" select="f:tw(' ', $font, $pt)"/>
    <xsl:iterate select="f:units($text)">
      <xsl:param name="done" as="xs:string*" select="()"/>
      <xsl:param name="cur" as="xs:string" select="''"/>
      <xsl:param name="w" as="xs:double" select="0"/>
      <xsl:on-completion select="if ($cur ne '') then ($done, $cur) else $done"/>
      <xsl:variable name="uw" select="f:tw(., $font, $pt)"/>
      <xsl:variable name="join" select="$cur ne '' and $w + $sp + $uw le $avail"/>
      <xsl:variable name="base" select="if ($cur ne '' and not($join)) then ($done, $cur) else $done"/>
      <xsl:choose>
        <xsl:when test="$join">
          <xsl:next-iteration>
            <xsl:with-param name="done" select="$done"/>
            <xsl:with-param name="cur" select="concat($cur, ' ', .)"/>
            <xsl:with-param name="w" select="$w + $sp + $uw"/>
          </xsl:next-iteration>
        </xsl:when>
        <xsl:when test="$uw le $avail">
          <xsl:next-iteration>
            <xsl:with-param name="done" select="$base"/>
            <xsl:with-param name="cur" select="."/>
            <xsl:with-param name="w" select="$uw"/>
          </xsl:next-iteration>
        </xsl:when>
        <xsl:otherwise>
          <xsl:variable name="chunks" select="f:chop(., $font, $pt, $avail)"/>
          <xsl:next-iteration>
            <xsl:with-param name="done" select="($base, $chunks[position() lt last()])"/>
            <xsl:with-param name="cur" select="$chunks[last()]"/>
            <xsl:with-param name="w" select="f:tw($chunks[last()], $font, $pt)"/>
          </xsl:next-iteration>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:iterate>
  </xsl:function>

  <!-- Feld einer Tabellenzeile (IG-MED20994Z5N-01): 12 pt einzeilig, sonst 10 pt (ein bis zwei Zeilen), danach wächst die Höhe.
       Ergebnis: pt, lines, h (Feldhöhe in mm) -->
  <xsl:function name="f:field" as="map(*)">
    <xsl:param name="text" as="xs:string*"/>
    <xsl:param name="avail" as="xs:double"/>
    <xsl:variable name="t" select="normalize-space(string-join($text, ' '))"/>
    <xsl:variable name="pt" as="xs:integer" select="if (f:tw($t, 'regular', 12) le $avail) then 12 else 10"/>
    <xsl:variable name="lines" as="xs:string*"
                  select="if ($t eq '') then () else if ($pt eq 12) then $t else f:wrap($t, 'regular', 10, $avail)"/>
    <xsl:sequence select="map{'pt': $pt, 'lines': $lines, 'h': count($lines) * $LH * $pt * $PT-MM}"/>
  </xsl:function>

  <!-- Form (IG-MED19844CVF-01): höchstens zwei Zeilen, vom Ende her gekürzt und mit "..." ergänzt -->
  <xsl:function name="f:field-form" as="map(*)">
    <xsl:param name="text" as="xs:string"/>
    <xsl:param name="avail" as="xs:double"/>
    <xsl:variable name="t" select="normalize-space($text)"/>
    <xsl:variable name="full" select="f:field($t, $avail)"/>
    <xsl:choose>
      <xsl:when test="count($full?lines) le 2">
        <xsl:sequence select="map{'pt': $full?pt, 'lines': $full?lines, 'h': $full?h}"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="l1" select="($full?lines)[1]"/>
        <xsl:variable name="rest" select="replace(substring($t, string-length($l1) + 1), '^ ', '')"/>
        <xsl:sequence select="map{'pt': 10, 'lines': ($l1, f:ellipsis($rest, 10, $avail)), 'h': 2 * $LH * 10 * $PT-MM}"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <xsl:function name="f:ellipsis" as="xs:string">
    <xsl:param name="text" as="xs:string"/>
    <xsl:param name="pt" as="xs:double"/>
    <xsl:param name="avail" as="xs:double"/>
    <xsl:variable name="cands" as="xs:string*"
                  select="for $i in reverse(1 to string-length($text)) return replace(substring($text, 1, $i), '\s+$', '')"/>
    <xsl:sequence select="concat(($cands[f:tw(concat(., '...'), 'regular', $pt) le $avail], '')[1], '...')"/>
  </xsl:function>

  <!-- Breite des Textbereichs einer Eintragsspalte c (Spaltenbreite - Ränder - Abstand) -->
  <xsl:function name="f:cw" as="xs:double">
    <xsl:param name="c" as="xs:integer"/>
    <xsl:sequence select="f:cw-span($c, $c)"/>
  </xsl:function>

  <xsl:function name="f:cw-span" as="xs:double">
    <xsl:param name="from" as="xs:integer"/>
    <xsl:param name="to" as="xs:integer"/>
    <xsl:sequence select="sum($COLS[position() ge $from and position() le $to])
                          - 2 * $PAD
                          - (if ($from eq 1) then $BW-THICK else $BW-DASH)
                          - (if ($to eq 11) then $BW-THICK else 0)"/>
  </xsl:function>

  <!-- ===== Daten ===== -->
  <!-- Zuordnung der Medication über die ID nach dem letzten "/" der Referenz -->
  <xsl:function name="f:medication" as="element()?">
    <xsl:param name="mr" as="element()"/>
    <xsl:variable name="id" select="tokenize(string(($mr/medicationReference/reference/@value)[1]), '/')[last()]"/>
    <xsl:sequence select="key('med-by-id', $id, root($mr))[1]"/>
  </xsl:function>

  <!-- Stärke strikt nach IG-MED54318LJQ-01: value und unit, getrennt durch " / "; sonst amountText -->
  <xsl:function name="f:qty" as="xs:string">
    <xsl:param name="q" as="element()?"/>
    <!-- ANNAHME: zwischen value und unit steht ein Leerzeichen (typografisch) -->
    <xsl:sequence select="if (exists($q/value/@value)) then string-join((f:num($q/value/@value), $q/unit/@value), ' ') else ''"/>
  </xsl:function>

  <xsl:function name="f:strength" as="xs:string">
    <xsl:param name="ing" as="element()"/>
    <xsl:variable name="structured" select="string-join((f:qty($ing/strength/numerator), f:qty($ing/strength/denominator))[. ne ''], ' / ')"/>
    <xsl:sequence select="if ($structured ne '') then $structured
                          else string(($ing/strength/extension[@url = $U-AMOUNT]/valueString/@value)[1])"/>
  </xsl:function>

  <!-- VORLÄUFIG: Regel für die Form bei mehreren Codings (informelle Einschätzung der gematik, keine Vorgabe der Spezifikation):
       Coding mit display vor Coding ohne display; bei mehreren Codings mit display IFA vor KBV; ohne display der code
       in derselben Reihenfolge (IFA vor KBV). Weitere Codings folgen nach KBV (ANNAHME). form.text wird nie ausgegeben. -->
  <xsl:template name="vorlaeufig-darreichungsform" as="xs:string">
    <xsl:param name="med" as="element()?"/>
    <xsl:variable name="codings" select="$med/form/coding"/>
    <xsl:variable name="ordered"
                  select="($codings[system/@value = $SYS-IFA],
                           $codings[system/@value = $SYS-KBV],
                           $codings[not(system/@value = ($SYS-IFA, $SYS-KBV))])"/>
    <xsl:variable name="with-display" select="$ordered[normalize-space(display/@value) ne ''][1]"/>
    <xsl:variable name="with-code" select="$ordered[normalize-space(code/@value) ne ''][1]"/>
    <xsl:sequence select="if (exists($with-display)) then string($with-display/display/@value)
                          else string($with-code/code/@value)"/>
  </xsl:template>

  <!-- IG-MED20676FFH-01: Dosierungstabelle nur, wenn alle dosageInstruction die Bedingungen erfüllen -->
  <xsl:function name="f:is-table" as="xs:boolean">
    <xsl:param name="mr" as="element()"/>
    <xsl:variable name="di" select="$mr/dosageInstruction"/>
    <xsl:variable name="units" select="$di/doseAndRate/doseQuantity/unit/@value"/>
    <xsl:sequence select="exists($di)
      and (every $d in $di satisfies (
             exists($d/timing/repeat/when)
             and exists($d/timing/repeat/frequency)
             and number($d/timing/repeat/period/@value) eq 1
             and string($d/timing/repeat/periodUnit/@value) eq 'd'
             (: ANNAHME: boundsPeriod (Anwendungszeitraum) verhindert die Tabelle nicht, siehe Beispiel-PDF :)
             and empty($d/timing/repeat/(timeOfDay | dayOfWeek | boundsDuration | boundsRange))
             and exists($d/doseAndRate/doseQuantity)
             and (every $q in $d/doseAndRate/doseQuantity satisfies exists($q/unit/@value))))
      and count(distinct-values($units)) eq 1"/>
  </xsl:function>

  <!-- ANNAHME: bei mehreren Dosierungen mit gleichem when-Code gilt die erste -->
  <xsl:function name="f:dose-value" as="xs:string">
    <xsl:param name="mr" as="element()"/>
    <xsl:param name="code" as="xs:string"/>
    <xsl:variable name="v" select="($mr/dosageInstruction[timing/repeat/when/@value = $code]/doseAndRate/doseQuantity/value/@value)[1]"/>
    <xsl:sequence select="if (exists($v)) then f:num($v) else '0'"/>
  </xsl:function>

  <!-- Dosierinformation (IG-MED72972QGC-01): Extension renderedDosageInstruction (Markdown unverändert als Klartext), sonst dosageInstruction.text -->
  <xsl:function name="f:dose-infos" as="xs:string*">
    <xsl:param name="mr" as="element()"/>
    <xsl:variable name="ext" select="($mr/extension[@url = $U-RENDERED]/valueMarkdown/@value)[1]"/>
    <xsl:sequence select="(if (exists($ext)) then string($ext) else $mr/dosageInstruction/text/@value ! string(.))
                          ! normalize-space(.)[. ne '']"/>
  </xsl:function>

  <!-- Zusatzzeile: Anwendungszeitraum (IG-MED66689BZJ-01), dann bei Textdosierung "Dosierung: ..." (IG-MED72972QGC-01,
       IG-MED84431U1K-01); je Textzeile map(t, ind) -->
  <xsl:function name="f:extra-lines" as="map(*)*">
    <xsl:param name="mr" as="element()"/>
    <xsl:param name="table" as="xs:boolean"/>
    <xsl:variable name="bp" select="($mr/dosageInstruction)[1]/timing/repeat/boundsPeriod"/>
    <xsl:variable name="s" select="string($bp/start/@value)"/>
    <xsl:variable name="e" select="string($bp/end/@value)"/>
    <xsl:if test="$s ne '' or $e ne ''">
      <xsl:sequence select="map{'t': concat('Anwendungszeitraum: ',
                                            if ($s ne '' and $e ne '') then concat('von ', f:bound($s), ' bis ', f:bound($e))
                                            else if ($s ne '') then concat('ab ', f:bound($s))
                                            else concat('bis ', f:bound($e)), '.'),
                                'ind': 0}"/>
    </xsl:if>
    <xsl:if test="not($table)">
      <xsl:variable name="infos" select="f:dose-infos($mr)"/>
      <xsl:variable name="ind" select="f:tw('Dosierung: ', 'regular', 12)"/>
      <xsl:for-each select="$infos">
        <xsl:variable name="k" select="position()"/>
        <!-- Mehrere Dosierinformationen: durch ";" und Zeilenumbruch getrennt; die Spezifikation verlangt ein "." am Ende
             ANNAHME: ein vorhandenes abschließendes ";" bzw. "." (vor ";") wird ersetzt statt verdoppelt; am Ende wird das "." nur
             ergänzt, wenn der Text noch nicht mit ".", "!" oder "?" endet -->
        <xsl:variable name="piece"
                      select="if ($k lt count($infos)) then concat(replace(., '[.;]$', ''), ';')
                              else (let $t := replace(., ';$', '') return if (matches($t, '[.!?]$')) then $t else concat($t, '.'))"/>
        <xsl:for-each select="f:wrap($piece, 'regular', 12, $ZW - $ind)">
          <xsl:variable name="first" select="$k eq 1 and position() eq 1"/>
          <xsl:sequence select="map{'t': if ($first) then concat('Dosierung: ', .) else ., 'ind': if ($first) then 0 else $ind}"/>
        </xsl:for-each>
      </xsl:for-each>
    </xsl:if>
  </xsl:function>

  <!-- ===== Läufe aus fett/normal gesetzten Wörtern (Name, Fußtext) ===== -->
  <xsl:function name="f:toks" as="map(*)*">
    <xsl:param name="text" as="xs:string*"/>
    <xsl:param name="bold" as="xs:boolean"/>
    <xsl:sequence select="for $w in tokenize(normalize-space(string-join($text, ' ')), ' ')[. ne ''] return map{'t': $w, 'b': $bold}"/>
  </xsl:function>

  <!-- Der Leerraum zwischen zwei Wörtern ist nur fett, wenn beide Wörter fett sind -->
  <xsl:function name="f:wrap-runs" as="array(*)*">
    <xsl:param name="toks" as="map(*)*"/>
    <xsl:param name="pt" as="xs:double"/>
    <xsl:param name="avail" as="xs:double"/>
    <xsl:iterate select="$toks">
      <xsl:param name="lines" as="array(*)*" select="()"/>
      <xsl:param name="cur" as="map(*)*" select="()"/>
      <xsl:param name="w" as="xs:double" select="0"/>
      <xsl:on-completion select="($lines, if (exists($cur)) then array{$cur} else ())"/>
      <xsl:variable name="b" select="boolean(.?b)"/>
      <xsl:variable name="tw" select="f:tw(.?t, if ($b) then 'bold' else 'regular', $pt)"/>
      <xsl:variable name="sp" select="if (empty($cur)) then 0
                                      else f:tw(' ', if ($b and boolean($cur[last()]?b)) then 'bold' else 'regular', $pt)"/>
      <xsl:choose>
        <xsl:when test="empty($cur) or $w + $sp + $tw le $avail">
          <xsl:next-iteration>
            <xsl:with-param name="lines" select="$lines"/>
            <xsl:with-param name="cur" select="($cur, .)"/>
            <xsl:with-param name="w" select="$w + $sp + $tw"/>
          </xsl:next-iteration>
        </xsl:when>
        <xsl:otherwise>
          <xsl:next-iteration>
            <xsl:with-param name="lines" select="($lines, array{$cur})"/>
            <xsl:with-param name="cur" select="."/>
            <xsl:with-param name="w" select="$tw"/>
          </xsl:next-iteration>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:iterate>
  </xsl:function>

  <xsl:template name="render-runs">
    <xsl:param name="toks" as="map(*)*"/>
    <xsl:for-each-group select="$toks" group-adjacent="boolean(.?b)">
      <xsl:if test="position() gt 1"><xsl:text> </xsl:text></xsl:if>
      <xsl:variable name="txt" select="string-join(current-group() ! .?t, ' ')"/>
      <xsl:choose>
        <xsl:when test="current-grouping-key()"><fo:inline font-weight="bold"><xsl:value-of select="$txt"/></fo:inline></xsl:when>
        <xsl:otherwise><xsl:value-of select="$txt"/></xsl:otherwise>
      </xsl:choose>
    </xsl:for-each-group>
  </xsl:template>

  <!-- ===== Dokument ===== -->
  <xsl:template match="/">
      <fo:root font-family="Liberation Sans" font-size="12pt" color="black" xml:lang="de" hyphenate="false">
      <fo:layout-master-set>
        <!-- 21,0 - 2 x 0,85 = 19,3 cm: Kopf 2,25 + Abstand 0,3 + Tabelle 15,75 + Fuß 1,0 (Tabellenkopf in region-before) -->
        <fo:simple-page-master master-name="emp" page-width="297mm" page-height="210mm" margin="8.5mm">
          <fo:region-body margin-top="{f:mm($HEAD-H + $GAP-H + $ROW)}" margin-bottom="{f:mm($FOOT-H)}"/>
          <fo:region-before extent="{f:mm($HEAD-H + $GAP-H + $ROW)}"/>
          <fo:region-after extent="{f:mm($FOOT-H)}"/>
        </fo:simple-page-master>
      </fo:layout-master-set>

      <fo:page-sequence master-reference="emp" initial-page-number="1">
        <fo:static-content flow-name="xsl-region-before">
          <xsl:call-template name="head-block"/>
          <!-- ANNAHME: Die Kopfzeile der Tabelle steht auf jeder Seite (die Tabelle existiert pro Seite genau einmal) -->
          <fo:block space-before="{f:mm($GAP-H)}">
            <xsl:call-template name="table-head"/>
          </fo:block>
        </fo:static-content>

        <fo:static-content flow-name="xsl-region-after">
          <xsl:call-template name="foot-block"/>
        </fo:static-content>

        <fo:flow flow-name="xsl-region-body">
          <xsl:for-each select="$items">
            <xsl:call-template name="entry"><xsl:with-param name="mr" select="."/></xsl:call-template>
          </xsl:for-each>
            <!-- ABWEICHUNG: ohne aktive Einträge bleibt der Tabellenbereich leer, das Dokument entsteht trotzdem;
                 die Marke liefert die Gesamtseitenzahl -->
          <fo:block id="emp-end" font-size="0pt" line-height="0pt" keep-with-previous.within-page="always"/>
        </fo:flow>
      </fo:page-sequence>
    </fo:root>
  </xsl:template>

  <!-- ===== Kopfbereich: Identifikationsblock (7,0 cm) und Administrationsblock (21 cm), je 2,25 cm hoch ===== -->
  <xsl:template name="head-block">
    <xsl:variable name="inner-h" select="$HEAD-H - 2 * $BW-SOLID"/>
    <xsl:variable name="half" select="$inner-h div 2"/>

    <!-- Name (IG-MED11815X3Q-01): nur name[use='official'], Präfix normal, Vorname(n) und Nachname fett -->
    <xsl:variable name="name" select="($patient/name[use/@value = 'official'])[1]"/>
    <xsl:variable name="name-toks" select="(f:toks($name/prefix/@value, false()),
                                            f:toks($name/given/@value, true()),
                                            f:toks($name/family/@value, true()))"/>
    <xsl:variable name="kvnr" select="string(($patient/identifier[system/@value = $SYS-KVNR]/value/@value)[1])"/>
    <xsl:variable name="birth" select="f:birth(string($patient/birthDate/@value))"/>

    <xsl:variable name="adm-w" select="$TOTAL-W - 70 - $BW-SOLID - 2 * $PAD-BLOCK"/>
    <xsl:variable name="right-w" select="max((f:tw('geb. am: ', 'regular', 14) + f:tw($birth, 'bold', 14),
                                              f:tw(concat('erstellt: ', $creationDateTime), 'regular', 14))) + 0.3"/>
    <xsl:variable name="sep" select="10"/>
    <xsl:variable name="left-w" select="$adm-w - $sep - $right-w"/>
    <xsl:variable name="for-w" select="f:tw('Für: ', 'regular', 14)"/>
    <xsl:variable name="name-lines" select="f:wrap-runs($name-toks, 14, $left-w - $for-w)"/>
    <!-- ANNAHME: Bricht der Name um, wächst das obere Zeilenband auf Kosten des unteren (bis zu drei Namenszeilen innerhalb der 2,25 cm).
         Mehr als drei Zeilen passen nicht in den Block, er wächst dann nach unten (Einschränkung). -->
    <!-- Obere Zeile oben, untere Zeile unten, jeweils ca. 2 mm Abstand der Schrift zum Rand (Oberkante der Großbuchstaben bzw. Grundlinie);
         die Zeilenhöhen von FOP gelten ohne Zellabstand -->
    <xsl:variable name="pad-top" select="1.5"/>
    <xsl:variable name="pad-bot" select="0.6"/>
    <xsl:variable name="top-h" select="max(($half, count($name-lines) * 15 * $PT-MM + $pad-top))"/>
    <xsl:variable name="bot-h" select="max(($inner-h - $top-h, 15 * $PT-MM + $pad-bot))"/>

    <fo:table table-layout="fixed" width="{f:mm($TOTAL-W)}" border-collapse="separate" border-separation="0pt">
      <fo:table-column column-width="70mm"/>
      <fo:table-column column-width="{f:mm($TOTAL-W - 70)}"/>
      <fo:table-body>
        <fo:table-row height="{f:mm($inner-h)}">
          <!-- Identifikationsblock (IG-MED46271FNY-02) -->
          <fo:table-cell border="{$SOLID}" padding-left="{f:mm($PAD-BLOCK)}" padding-right="{f:mm($PAD-BLOCK)}" padding-top="0mm" padding-bottom="0mm">
            <fo:table table-layout="fixed" width="{f:mm(70 - 2 * $BW-SOLID - 2 * $PAD-BLOCK)}">
              <fo:table-column column-width="{f:mm(70 - 2 * $BW-SOLID - 2 * $PAD-BLOCK)}"/>
              <fo:table-body>
                <fo:table-row height="{f:mm($top-h - $pad-top)}">
                  <fo:table-cell display-align="before" padding-top="{f:mm($pad-top)}">
                    <!-- Zeilenhöhe so gewählt, dass die Großbuchstaben (20 pt) wie bei "Für: ..." ca. 2 mm unter dem oberen Rand beginnen -->
                    <fo:block font-size="20pt" font-weight="bold" line-height="18.9pt" hyphenate="false"
                              wrap-option="no-wrap">Medikationsplan
                    </fo:block>
                  </fo:table-cell>
                </fo:table-row>
                <fo:table-row height="{f:mm($bot-h - $pad-bot)}">
                  <fo:table-cell display-align="after" padding-bottom="{f:mm($pad-bot)}">
                    <fo:block font-size="14pt" line-height="15pt" wrap-option="no-wrap">Seite
                      <fo:page-number/>
                      von
                      <fo:page-number-citation-last ref-id="emp-end"/>
                    </fo:block>
                  </fo:table-cell>
                </fo:table-row>
              </fo:table-body>
            </fo:table>
          </fo:table-cell>

          <!-- Administrationsblock (IG-MED11815X3Q-01); der linke Rand ist der rechte Rand des Identifikationsblocks -->
          <fo:table-cell border-top="{$SOLID}" border-bottom="{$SOLID}" border-right="{$SOLID}"
                         padding-left="{f:mm($PAD-BLOCK)}" padding-right="{f:mm($PAD-BLOCK)}" padding-top="0mm" padding-bottom="0mm">
            <fo:table table-layout="fixed" width="{f:mm($adm-w)}">
              <fo:table-column column-width="{f:mm($left-w)}"/>
              <fo:table-column column-width="{f:mm($sep)}"/>
              <fo:table-column column-width="{f:mm($right-w)}"/>
              <fo:table-body>
                <fo:table-row height="{f:mm($top-h - $pad-top)}">
                  <fo:table-cell display-align="before" padding-top="{f:mm($pad-top)}">
                    <xsl:for-each select="$name-lines">
                      <fo:block font-size="14pt" line-height="15pt" wrap-option="no-wrap">
                        <xsl:if test="position() gt 1"><xsl:attribute name="margin-left" select="f:mm($for-w)"/></xsl:if>
                        <xsl:if test="position() eq 1"><xsl:text>Für: </xsl:text></xsl:if>
                        <xsl:call-template name="render-runs"><xsl:with-param name="toks" select="array:flatten(.)"/></xsl:call-template>
                      </fo:block>
                    </xsl:for-each>
                    <xsl:if test="empty($name-lines)">
                      <fo:block font-size="14pt" line-height="15pt" wrap-option="no-wrap">Für: </fo:block>
                    </xsl:if>
                  </fo:table-cell>
                  <fo:table-cell><fo:block/></fo:table-cell>
                  <fo:table-cell display-align="before" padding-top="{f:mm($pad-top)}">
                    <fo:block font-size="14pt" line-height="15pt" wrap-option="no-wrap" text-align="end">
                      <xsl:text>geb. am: </xsl:text><fo:inline font-weight="bold"><xsl:value-of select="$birth"/></fo:inline>
                    </fo:block>
                  </fo:table-cell>
                </fo:table-row>
                <fo:table-row height="{f:mm($bot-h - $pad-bot)}">
                  <fo:table-cell display-align="after" padding-bottom="{f:mm($pad-bot)}">
                    <fo:block font-size="14pt" line-height="15pt" wrap-option="no-wrap">Versichertennummer: <xsl:value-of select="$kvnr"/></fo:block>
                  </fo:table-cell>
                  <fo:table-cell><fo:block/></fo:table-cell>
                  <fo:table-cell display-align="after" padding-bottom="{f:mm($pad-bot)}">
                    <fo:block font-size="14pt" line-height="15pt" wrap-option="no-wrap" text-align="end">erstellt: <xsl:value-of select="$creationDateTime"/></fo:block>
                  </fo:table-cell>
                </fo:table-row>
              </fo:table-body>
            </fo:table>
          </fo:table-cell>
        </fo:table-row>
      </fo:table-body>
    </fo:table>
  </xsl:template>

    <!-- ===== Tabellenkopf (IG-MED61434W6C-02): 14 pt fett; Spalte 5 in vier Zellen mit Liberation Sans Narrow 8 pt ===== -->
  <!-- ANNAHME: Kopfzeile ringsum 0,5 pt durchgehend, ein Rand je Spaltengrenze; die 3-pt-Ränder gelten nur für eMP-Einträge -->
  <xsl:template name="table-head">
    <fo:table table-layout="fixed" width="{f:mm($TOTAL-W)}" border-collapse="separate" border-separation="0pt">
      <xsl:for-each select="$COLS"><fo:table-column column-width="{f:mm(.)}"/></xsl:for-each>
      <fo:table-body>
        <fo:table-row height="{f:mm($ROW - 2 * $BW-SOLID)}">
          <xsl:for-each select="('Wirkstoff', 'Handelsname', 'Stärke', 'Form')">
            <xsl:call-template name="head-cell"><xsl:with-param name="text" select="."/><xsl:with-param name="last" select="false()"/></xsl:call-template>
          </xsl:for-each>
          <xsl:call-template name="dose-head-cell"><xsl:with-param name="lines" select="('mor-', 'gens')"/></xsl:call-template>
          <xsl:call-template name="dose-head-cell"><xsl:with-param name="lines" select="('mit-', 'tags')"/></xsl:call-template>
          <xsl:call-template name="dose-head-cell"><xsl:with-param name="lines" select="('abends')"/></xsl:call-template>
          <xsl:call-template name="dose-head-cell">
            <xsl:with-param name="lines" select="('zur', 'Nacht')"/>
          </xsl:call-template>
          <xsl:call-template name="head-cell"><xsl:with-param name="text" select="'Einheit'"/><xsl:with-param name="last" select="false()"/></xsl:call-template>
          <xsl:call-template name="head-cell"><xsl:with-param name="text" select="'Hinweise'"/><xsl:with-param name="last" select="false()"/></xsl:call-template>
          <xsl:call-template name="head-cell"><xsl:with-param name="text" select="'Grund'"/><xsl:with-param name="last" select="true()"/></xsl:call-template>
        </fo:table-row>
      </fo:table-body>
    </fo:table>
  </xsl:template>

  <xsl:template name="head-cell">
    <xsl:param name="text" as="xs:string"/>
    <xsl:param name="last" as="xs:boolean"/>
    <fo:table-cell display-align="center" border-top="{$SOLID}" border-bottom="{$SOLID}" border-left="{$SOLID}"
                   padding-left="{f:mm($PAD)}" padding-right="{f:mm($PAD)}" padding-top="0mm" padding-bottom="0mm">
      <xsl:if test="$last"><xsl:attribute name="border-right" select="$SOLID"/></xsl:if>
      <fo:block font-size="14pt" font-weight="bold" line-height="{f:pt(14 * $LH)}" wrap-option="no-wrap"><xsl:value-of select="$text"/></fo:block>
    </fo:table-cell>
  </xsl:template>

  <!-- Die Abstandsregel von 1,0 bis 1,25 mm gilt in diesen Zellen nicht (IG-MED61434W6C-02) -->
  <xsl:template name="dose-head-cell">
    <xsl:param name="lines" as="xs:string+"/>
    <fo:table-cell display-align="center" border-top="{$SOLID}" border-bottom="{$SOLID}" border-left="{$SOLID}" padding="0mm">
      <xsl:for-each select="$lines">
          <!-- ANNAHME: Liberation Sans Narrow; passt ein Text nicht in die 8 mm breite Zelle ("abends"), wird die Laufweite verringert -->
        <xsl:variable name="over" select="f:tw(., 'narrow', 8) - (8 - $BW-SOLID - 0.2)"/>
          <fo:block font-family="'Liberation Sans Narrow'" font-size="8pt" font-weight="normal"
                    line-height="{f:pt(8 * $LH)}"
                  text-align="center" wrap-option="no-wrap">
          <xsl:if test="$over gt 0">
            <xsl:attribute name="letter-spacing" select="f:pt(- $over div (string-length(.) * $PT-MM))"/>
          </xsl:if>
          <xsl:value-of select="."/>
        </fo:block>
      </xsl:for-each>
    </fo:table-cell>
  </xsl:template>

  <!-- ===== Fußbereich (IG-MED93441Y6A-01, IG-MED59609CUM): obere Linie, 1,0 cm hoch, 8 pt ===== -->
  <xsl:template name="foot-block">
    <xsl:variable name="right-text" select="'de-DE Version 1.0'"/>
    <xsl:variable name="right-w" select="f:tw($right-text, 'regular', 8) + 2 * $PAD + 1"/>
    <xsl:variable name="left-w" select="$TOTAL-W - $right-w"/>
    <!-- ABWEICHUNG: Der Text ist bei 8 pt rund 282,6 mm breit und passt nicht einzeilig in 280 mm; Umbruch auf zwei Zeilen -->
    <xsl:variable name="toks" select="(f:toks('Wichtiger Hinweis:', true()),
                                       f:toks('Dieser Medikationsplan wurde', false()),
                                       f:toks('nicht', true()),
                                       f:toks('aus einer elektronischen Patientenakte (ePA) heraus erstellt. Sofern eine ePA vorhanden ist, befinden sich dort ggf. weitere, abweichende oder aktuellere Informationen.', false()))"/>
    <xsl:variable name="lines" select="f:wrap-runs($toks, 8, $left-w - 2 * $PAD - 2)"/>
    <fo:table table-layout="fixed" width="{f:mm($TOTAL-W)}" border-collapse="separate" border-separation="0pt">
      <fo:table-column column-width="{f:mm($left-w)}"/>
      <fo:table-column column-width="{f:mm($right-w)}"/>
      <fo:table-body>
        <fo:table-row height="{f:mm($FOOT-H - $BW-SOLID)}">
          <fo:table-cell display-align="center" border-top="{$SOLID}" padding-left="{f:mm($PAD)}" padding-right="{f:mm($PAD)}" padding-top="0mm" padding-bottom="0mm">
            <xsl:for-each select="$lines">
              <fo:block font-size="8pt" line-height="{f:pt(8 * $LH)}" wrap-option="no-wrap">
                <xsl:call-template name="render-runs"><xsl:with-param name="toks" select="array:flatten(.)"/></xsl:call-template>
              </fo:block>
            </xsl:for-each>
          </fo:table-cell>
          <fo:table-cell display-align="center" border-top="{$SOLID}" padding-left="{f:mm($PAD)}" padding-right="{f:mm($PAD)}" padding-top="0mm" padding-bottom="0mm">
            <fo:block font-size="8pt" line-height="{f:pt(8 * $LH)}" wrap-option="no-wrap" text-align="end"><xsl:value-of select="$right-text"/></fo:block>
          </fo:table-cell>
        </fo:table-row>
      </fo:table-body>
    </fo:table>
  </xsl:template>

  <!-- ===== eMP-Eintrag (IG-MED61434W6C-02) ===== -->
  <xsl:template name="field-block">
    <xsl:param name="fld" as="map(*)"/>
    <xsl:for-each select="$fld?lines">
      <fo:block font-size="{$fld?pt}pt" line-height="{f:pt($fld?pt * $LH)}" wrap-option="no-wrap"><xsl:value-of select="."/></fo:block>
    </xsl:for-each>
    <xsl:if test="empty($fld?lines)"><fo:block/></xsl:if>
  </xsl:template>

  <!-- Wirkstoff-/Stärke-Zelle: je Wirkstoff ein Streifen gleicher Höhe in beiden Spalten (IG-MED03519KYL-02) -->
  <xsl:template name="band-content">
    <xsl:param name="bands" as="map(*)+"/>
    <xsl:param name="key" as="xs:string"/>
    <xsl:param name="heights" as="xs:double+"/>
    <xsl:choose>
      <xsl:when test="count($bands) eq 1">
        <xsl:call-template name="field-block"><xsl:with-param name="fld" select="$bands[1]($key)"/></xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:for-each select="$bands">
          <xsl:variable name="i" select="position()"/>
          <fo:block-container height="{f:mm($heights[$i])}" display-align="center">
            <xsl:call-template name="field-block"><xsl:with-param name="fld" select=".($key)"/></xsl:call-template>
          </fo:block-container>
        </xsl:for-each>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- Ränder: je Grenze nur eine Linie (benachbarte Linien werden zu einer) -->
  <xsl:template name="cell-attrs">
    <xsl:param name="first" as="xs:boolean" select="false()"/>
    <xsl:param name="last" as="xs:boolean" select="false()"/>
    <xsl:param name="top" as="xs:string"/>
    <xsl:param name="bottom" as="xs:string"/>
    <xsl:attribute name="border-top" select="$top"/>
    <xsl:attribute name="border-bottom" select="$bottom"/>
    <xsl:attribute name="border-left" select="if ($first) then $THICK else $DASH"/>
    <xsl:attribute name="border-right" select="if ($last) then $THICK else 'none'"/>
    <xsl:attribute name="padding-left" select="f:mm($PAD)"/>
    <xsl:attribute name="padding-right" select="f:mm($PAD)"/>
    <xsl:attribute name="padding-top" select="'0mm'"/>
    <xsl:attribute name="padding-bottom" select="'0mm'"/>
    <xsl:attribute name="display-align" select="'center'"/>
  </xsl:template>

  <xsl:template name="entry">
    <xsl:param name="mr" as="element()"/>

    <xsl:variable name="med" select="f:medication($mr)"/>
    <xsl:variable name="ings" select="$med/ingredient"/>

    <!-- Wirkstoff und Stärke (IG-MED03519KYL-02): je Bestandteil ein Streifen von mindestens 0,875 cm -->
    <xsl:variable name="bands" as="map(*)+">
      <xsl:choose>
        <xsl:when test="count($ings) gt 3">
          <xsl:variable name="w" select="f:field('Mehr als drei', f:cw(1))"/>
          <xsl:sequence select="map{'w': $w, 's': f:field('', f:cw(3)), 'h': $w?h}"/>
        </xsl:when>
        <xsl:when test="exists($ings)">
          <xsl:for-each select="$ings">
            <xsl:variable name="w" select="f:field(itemCodeableConcept/text/@value ! string(.), f:cw(1))"/>
            <xsl:variable name="s" select="f:field(f:strength(.), f:cw(3))"/>
            <xsl:sequence select="map{'w': $w, 's': $s, 'h': if (count($ings) gt 1) then max(($ROW, $w?h, $s?h)) else max(($w?h, $s?h))}"/>
          </xsl:for-each>
        </xsl:when>
        <xsl:otherwise>
          <xsl:sequence select="map{'w': f:field('', f:cw(1)), 's': f:field('', f:cw(3)), 'h': 0}"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>

    <xsl:variable name="form-text" as="xs:string">
      <xsl:call-template name="vorlaeufig-darreichungsform"><xsl:with-param name="med" select="$med"/></xsl:call-template>
    </xsl:variable>
    <xsl:variable name="trade" select="f:field($med/code/text/@value ! string(.), f:cw(2))"/>
    <xsl:variable name="form" select="f:field-form($form-text, f:cw(4))"/>
    <xsl:variable name="note" select="f:field($mr/extension[@url = $U-NOTE]/valueAnnotation/text/@value ! string(.), f:cw(10))"/>
    <xsl:variable name="reason" select="f:field($mr/extension[@url = $U-REASON]/valueString/@value ! string(.), f:cw(11))"/>

    <!-- Dosierung (IG-MED20676FFH-01, IG-MED20374GEG-01, IG-MED72972QGC-01) -->
    <xsl:variable name="table" select="f:is-table($mr)"/>
    <xsl:variable name="extra" select="f:extra-lines($mr, $table)"/>
    <xsl:variable name="dose" as="map(*)*">
      <xsl:if test="$table">
        <xsl:for-each select="$WHEN-CODES">
          <xsl:sequence select="f:field(f:dose-value($mr, .), f:cw(4 + position()))"/>
        </xsl:for-each>
      </xsl:if>
    </xsl:variable>
    <xsl:variable name="unit" select="if ($table) then f:field(string(($mr/dosageInstruction/doseAndRate/doseQuantity/unit/@value)[1]), f:cw(9)) else ()"/>
    <xsl:variable name="see-next"
                  select="if (not($table) and exists($extra)) then f:field('siehe nächste Zeile', f:cw-span(5, 9)) else f:field('', f:cw-span(5, 9))"/>

    <xsl:variable name="has-extra" select="exists($extra)"/>
    <!-- Summe der Rahmenbreiten der Medikationszeile; FOP addiert sie zur Zeilenhöhe -->
    <xsl:variable name="b1" select="$BW-SOLID + (if ($has-extra) then 0 else $BW-SOLID)"/>
    <xsl:variable name="band-sum" select="sum($bands ! .?h)"/>
    <xsl:variable name="h1" select="max(($ROW, $band-sum + $b1, ($trade?h, $form?h, $note?h, $reason?h, $dose ! .?h, $unit?h, $see-next?h) ! (. + $b1)))"/>
    <xsl:variable name="band-h" select="for $b in $bands return $b?h + ($h1 - $b1 - $band-sum) div count($bands)"/>
    <xsl:variable name="h2" select="max(($ROW, count($extra) * $LH * 12 * $PT-MM + $BW-DASH + $BW-SOLID))"/>

    <!-- 1,8 mm Abstand über jedem Eintrag; Medikationszeile und Zusatzzeile bleiben auf einer Seite (IG-MED61434W6C-02) -->
    <fo:block space-before="1.8mm" space-before.conditionality="retain" keep-together.within-page="always">
      <fo:table table-layout="fixed" width="{f:mm($TOTAL-W)}" border-collapse="separate" border-separation="0pt" keep-together.within-page="always">
        <xsl:for-each select="$COLS"><fo:table-column column-width="{f:mm(.)}"/></xsl:for-each>
        <fo:table-body>
          <!-- Medikationszeile: Außenränder 3 pt links/rechts, oben/unten 0,5 pt, innen gestrichelt -->
          <fo:table-row height="{f:mm($h1 - $b1)}">
            <xsl:if test="$has-extra"><xsl:attribute name="keep-with-next.within-page" select="'always'"/></xsl:if>
            <fo:table-cell>
              <xsl:call-template name="cell-attrs">
                <xsl:with-param name="first" select="true()"/>
                <xsl:with-param name="top" select="$SOLID"/>
                <xsl:with-param name="bottom" select="if ($has-extra) then 'none' else $SOLID"/>
              </xsl:call-template>
              <xsl:call-template name="band-content">
                <xsl:with-param name="bands" select="$bands"/><xsl:with-param name="key" select="'w'"/><xsl:with-param name="heights" select="$band-h"/>
              </xsl:call-template>
            </fo:table-cell>
            <fo:table-cell>
              <xsl:call-template name="cell-attrs">
                <xsl:with-param name="top" select="$SOLID"/>
                <xsl:with-param name="bottom" select="if ($has-extra) then 'none' else $SOLID"/>
              </xsl:call-template>
              <xsl:call-template name="field-block"><xsl:with-param name="fld" select="$trade"/></xsl:call-template>
            </fo:table-cell>
            <fo:table-cell>
              <xsl:call-template name="cell-attrs">
                <xsl:with-param name="top" select="$SOLID"/>
                <xsl:with-param name="bottom" select="if ($has-extra) then 'none' else $SOLID"/>
              </xsl:call-template>
              <xsl:call-template name="band-content">
                <xsl:with-param name="bands" select="$bands"/><xsl:with-param name="key" select="'s'"/><xsl:with-param name="heights" select="$band-h"/>
              </xsl:call-template>
            </fo:table-cell>
            <fo:table-cell>
              <xsl:call-template name="cell-attrs">
                <xsl:with-param name="top" select="$SOLID"/>
                <xsl:with-param name="bottom" select="if ($has-extra) then 'none' else $SOLID"/>
              </xsl:call-template>
              <xsl:call-template name="field-block"><xsl:with-param name="fld" select="$form"/></xsl:call-template>
            </fo:table-cell>
            <xsl:choose>
              <xsl:when test="$table">
                <xsl:for-each select="$dose">
                  <fo:table-cell>
                    <xsl:call-template name="cell-attrs">
                      <xsl:with-param name="top" select="$SOLID"/>
                      <xsl:with-param name="bottom" select="if ($has-extra) then 'none' else $SOLID"/>
                    </xsl:call-template>
                    <xsl:call-template name="field-block"><xsl:with-param name="fld" select="."/></xsl:call-template>
                  </fo:table-cell>
                </xsl:for-each>
                <fo:table-cell>
                  <xsl:call-template name="cell-attrs">
                    <xsl:with-param name="top" select="$SOLID"/>
                    <xsl:with-param name="bottom" select="if ($has-extra) then 'none' else $SOLID"/>
                  </xsl:call-template>
                  <xsl:call-template name="field-block"><xsl:with-param name="fld" select="$unit"/></xsl:call-template>
                </fo:table-cell>
              </xsl:when>
              <xsl:otherwise>
                <!-- IG-MED72972QGC-01: Spalte 5 (alle vier Zellen) und Spalte 6 sind zusammengefasst -->
                <fo:table-cell number-columns-spanned="5">
                  <xsl:call-template name="cell-attrs">
                    <xsl:with-param name="top" select="$SOLID"/>
                    <xsl:with-param name="bottom" select="if ($has-extra) then 'none' else $SOLID"/>
                  </xsl:call-template>
                  <xsl:call-template name="field-block"><xsl:with-param name="fld" select="$see-next"/></xsl:call-template>
                </fo:table-cell>
              </xsl:otherwise>
            </xsl:choose>
            <fo:table-cell>
              <xsl:call-template name="cell-attrs">
                <xsl:with-param name="top" select="$SOLID"/>
                <xsl:with-param name="bottom" select="if ($has-extra) then 'none' else $SOLID"/>
              </xsl:call-template>
              <xsl:call-template name="field-block"><xsl:with-param name="fld" select="$note"/></xsl:call-template>
            </fo:table-cell>
            <fo:table-cell>
              <xsl:call-template name="cell-attrs">
                <xsl:with-param name="last" select="true()"/>
                <xsl:with-param name="top" select="$SOLID"/>
                <xsl:with-param name="bottom" select="if ($has-extra) then 'none' else $SOLID"/>
              </xsl:call-template>
              <xsl:call-template name="field-block"><xsl:with-param name="fld" select="$reason"/></xsl:call-template>
            </fo:table-cell>
          </fo:table-row>

          <!-- Zusatzzeile: untrennbar an die Medikationszeile gebunden -->
          <xsl:if test="$has-extra">
            <fo:table-row height="{f:mm($h2 - $BW-DASH - $BW-SOLID)}">
              <fo:table-cell number-columns-spanned="11">
                <xsl:call-template name="cell-attrs">
                  <xsl:with-param name="first" select="true()"/>
                  <xsl:with-param name="last" select="true()"/>
                  <xsl:with-param name="top" select="$DASH"/>
                  <xsl:with-param name="bottom" select="$SOLID"/>
                </xsl:call-template>
                <xsl:for-each select="$extra">
                  <fo:block font-size="12pt" line-height="{f:pt(12 * $LH)}" wrap-option="no-wrap">
                    <xsl:if test=".?ind gt 0"><xsl:attribute name="margin-left" select="f:mm(.?ind)"/></xsl:if>
                    <xsl:value-of select=".?t"/>
                  </fo:block>
                </xsl:for-each>
              </fo:table-cell>
            </fo:table-row>
          </xsl:if>
        </fo:table-body>
      </fo:table>
    </fo:block>
  </xsl:template>

</xsl:stylesheet>
