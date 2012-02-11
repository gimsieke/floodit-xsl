<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet 
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:fi="http://fischer-imsieke.de/namespace/floodit"
  xmlns:ixsl="http://saxonica.com/ns/interactiveXSLT"
  xmlns:prop="http://saxonica.com/ns/html-property"
  xmlns:style="http://saxonica.com/ns/html-style-property"
  extension-element-prefixes="ixsl"
  version="2.0"  
  exclude-result-prefixes="fi xs"
  >

  <xsl:param name="board-size" as="xs:integer" select="14" />
  <xsl:param name="max-moves" as="xs:integer" select="25" />
  <xsl:param name="num-colors" as="xs:integer" select="6" />
  <xsl:param name="hint-lookahead-depth" as="xs:integer" select="3" />
  <xsl:param name="debug" as="xs:string" select="'no'" />


  <xsl:template name="main">
    <xsl:result-document href="#maxsteps" method="ixsl:replace-content">
      <xsl:value-of select="$max-moves"/>
    </xsl:result-document>
    <xsl:call-template name="step">
      <xsl:with-param name="count" select="0" />
    </xsl:call-template>
    <xsl:variable name="initial-board" as="element(fi:board)" select="fi:group-board(fi:create-board($board-size, $num-colors))" />
    <xsl:apply-templates select="$initial-board" mode="render" />
    <xsl:result-document href="#rep" method="ixsl:replace-content">
      <xsl:sequence select="$initial-board"/>
    </xsl:result-document>
    <xsl:call-template name="controls" />
  </xsl:template>

  <xsl:template match="input[@id eq 'hintbutton']" mode="ixsl:onclick">
    <xsl:if test="$debug eq 'yes'">
      <xsl:result-document href="#scenarios" method="ixsl:replace-content">
        <xsl:sequence select="fi:scenarios(ixsl:page()//div[@id eq 'rep']/*:board, $hint-lookahead-depth)" />
      </xsl:result-document>
    </xsl:if>
    <xsl:for-each select="ixsl:page()//*[@id eq 'hint']">
      <ixsl:set-attribute name="style:background-color" select="fi:hint($hint-lookahead-depth, ixsl:page()//*[@id eq 'rep'])" />
    </xsl:for-each>
  </xsl:template>

  <xsl:function name="fi:hint" as="xs:string">
    <xsl:param name="lookahead" as="xs:integer" />
    <xsl:param name="board" as="element(board)" />
    <xsl:variable name="scenarios" select="fi:scenarios(ixsl:page()//div[@id eq 'rep']/*:board, $hint-lookahead-depth)" as="element(fi:scenario)" />
    <xsl:variable name="max" select="xs:integer(max($scenarios//fi:scenario/@score))" as="xs:integer" />
    <xsl:sequence select="if (count($scenarios//fi:scenario) eq 1) 
                          then $scenarios/*/@color
                          else ($scenarios//fi:scenario[xs:integer(@score) eq $max])[1]/ancestor::fi:scenario[last() - 1]/@color" />
  </xsl:function>

  <xsl:function name="fi:scenarios" as="element(fi:scenario)?" >
    <!-- calculates scores (in terms of max. main area sizes) 
         for the next $depth moves and all possible color options -->
    <xsl:param name="board" as="element(*)" />
    <xsl:param name="depth" as="xs:integer" />
    <!-- watch out when developing multiplayer mode: explicit reference to x=1,y=1 here: -->
    <xsl:variable name="main-area" select="$board/*:area[*:square[@x eq '1' and @y eq '1']]" as="element(*)" />
    <fi:scenario color="{$main-area/@color}" score="{count($main-area/*:square)}">
      <xsl:if test="$depth gt 0 and (count($board/*:area) gt 1)">
        <!--         <xsl:for-each select="$colors[position() le $num-colors][not(. eq $main-area/@color)]"> -->
        <xsl:variable name="adjacent-colors" select="distinct-values(fi:neighbors($main-area/*:square[not(@inside)], $board//*:square[not(@inside)])/../@color)" as="xs:string+"/>
        <xsl:for-each select="$adjacent-colors">
          <xsl:sequence select="fi:scenarios(fi:flood(1, 1, $board, .), $depth - 1)" />
        </xsl:for-each>
      </xsl:if>
    </fi:scenario>
  </xsl:function>

  <xsl:variable name="colors" as="xs:string+" 
    select="('#22f', '#f9b', '#ff3', '#f33', '#2b4', '#3ff', 'brown', 'purple', 'black', 'orange', 'gray')" />

  <xsl:template name="controls">
    <xsl:result-document href="#controls" method="ixsl:replace-content">
      <table>
        <tbody>
          <tr>
            <xsl:for-each select="$colors[position() le $num-colors]">
              <td id="{translate(., '#', '_')}" style="background-color:{.}">&#xfeff;</td>
            </xsl:for-each>
          </tr>
        </tbody>
      </table>
    </xsl:result-document>
  </xsl:template>

  <xsl:template name="score">
    <xsl:param name="moves" as="xs:integer" />
    <xsl:result-document href="#score" method="ixsl:replace-content">
      <xsl:value-of select="xs:integer(ixsl:page()//*[@id eq 'score']) + (10 * fi:pow2($max-moves - $moves))"/>
    </xsl:result-document>
  </xsl:template>

  <xsl:template name="step">
    <xsl:param name="count" as="xs:integer" />
    <xsl:result-document href="#step" method="ixsl:replace-content">
      <xsl:value-of select="$count"/>
    </xsl:result-document>
  </xsl:template>

  <xsl:function name="fi:create-board" as="element(fi:board)">
    <xsl:param name="size" as="xs:integer" />
    <xsl:param name="colorcount" as="xs:integer" />
    <!-- namespaces or prefixes aren't really necessary because they get discarded anyway when the elements are added to the page's DOM --> 
    <fi:board>
      <xsl:for-each select="1 to $size">
        <xsl:variable name="x" select="." as="xs:integer" />
        <xsl:for-each select="1 to $size">
          <xsl:variable name="y" select="." as="xs:integer" />
          <xsl:variable name="rnd" select="fi:rnd()" as="xs:integer" />
          <fi:square x="{$x}" y="{$y}" color="{$colors[$rnd]}" nc="{fi:neighborcount($x, $y)}" />
        </xsl:for-each>
      </xsl:for-each>
    </fi:board>
  </xsl:function>

  <xsl:function name="fi:group-board" as="element(fi:board)">
    <xsl:param name="board" as="element(fi:board)" />
    <fi:board>
      <xsl:copy-of select="$board/@*" />
      <xsl:sequence select="fi:group-squares($board/fi:square[1], (), $board/fi:square)" />
    </fi:board>
  </xsl:function>

  <!-- xsl:iterate might come in handy here. Without it, some recursion is necessary. -->
  <xsl:function name="fi:group-squares" as="element(*)+"><!-- result: (fi:square | fi:area)* -->
    <xsl:param name="square" as="element(fi:square)*" /><!-- not necessarily a single square. Could be all squares of an area. -->
    <xsl:param name="basket" as="element(*)*" /><!-- neighbors that have been grouped so far -->
    <xsl:param name="squares-and-areas" as="element(*)+" /><!-- twofold: the intermediate result (area elements) and the yet ungrouped squares -->

    <xsl:choose>
      <xsl:when test="exists($square)"><!-- there are ungrouped squares yet -->
        <!-- Neighbors of the same colour that are not already collected in the $basket: -->
        <xsl:variable name="neighbors" 
          select="fi:neighbors($square, $squares-and-areas/self::fi:square)
                    [@color = $square/@color]
                    [every $sq in $basket satisfies (not($sq is .))]" />
        <xsl:choose>
          <xsl:when test="exists($neighbors)">
            <xsl:sequence select="fi:group-squares($neighbors, ($square union $basket), $squares-and-areas)" />
          </xsl:when>
          <xsl:otherwise>
            <xsl:variable name="new-squares-and-areas" as="element(*)+">
              <fi:area color="{$square[1]/@color}">
                <xsl:apply-templates select="($basket union $square)" mode="group"/>
              </fi:area>
              <xsl:sequence select="$squares-and-areas except ($square union $basket)" />
            </xsl:variable>
            <xsl:sequence select="fi:group-squares(($new-squares-and-areas/self::fi:square)[1], (), $new-squares-and-areas)" />
          </xsl:otherwise>
        </xsl:choose>
      </xsl:when>
      <xsl:otherwise>
        <xsl:sequence select="$squares-and-areas" />
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <xsl:template match="fi:square/@color" mode="group" />

  <xsl:function name="fi:neighbors" as="element(*)*"><!-- fi:square or square -->
    <xsl:param name="square" as="element(*)+" /><!-- fi:square or square; a single one or all squares of an area -->
    <xsl:param name="squares" as="element(*)+" /><!-- fi:square or square; the remainder of the board's squares -->
    <xsl:sequence select="for $sq in $square return
                          (
                            $squares[@x eq $sq/@x][abs(@y - $sq/@y) eq 1]
                            union
                            $squares[@y eq $sq/@y][abs(@x - $sq/@x) eq 1]
                          )
                          except $square
                          "/>
  </xsl:function>

  <xsl:template match="div[@id eq 'controls']//td" mode="ixsl:onclick">
    <xsl:variable name="color" select="translate(@id, '_', '#')" as="xs:string" />
    <xsl:variable name="x" select="1" as="xs:integer" /><!-- x=1,x=1 is the default for a single-player game. -->
    <xsl:variable name="y" select="1" as="xs:integer" /><!-- Multiplayer not implemented yet, though. -->
    <!-- The @id attributes of the controls table's tds contain the color values (# replaced with _): -->
    <xsl:variable name="current-color" select="ixsl:page()//*[@id eq 'rep']/*:board/*:area[*:square[xs:integer(@x) eq $x and xs:integer(@y) eq $y]]/@color" />

    <xsl:if test="$color ne $current-color">
      <xsl:variable name="flooded" as="element(*)?" select="fi:flood(xs:integer($x), xs:integer($y), ixsl:page()//div[@id eq 'rep']/*:board, $color)" />
      <xsl:result-document href="#rep" method="ixsl:replace-content">
        <xsl:sequence select="$flooded" />
      </xsl:result-document>
  
      <xsl:apply-templates select="$flooded" mode="render" />
  
      <xsl:variable name="step" as="xs:integer" select="xs:integer(ixsl:page()//*[@id eq 'step']) + 1" />
      <xsl:call-template name="step">
        <xsl:with-param name="count" select="$step" />
      </xsl:call-template>
      <xsl:choose>
        <xsl:when test="count($flooded/*:area) eq 1">
          <xsl:call-template name="score">
            <xsl:with-param name="moves" select="$step" />
          </xsl:call-template>
          <ixsl:schedule-action wait="1000">
            <xsl:call-template name="main" />
          </ixsl:schedule-action>
        </xsl:when>
        <xsl:otherwise>
          <xsl:choose>
            <xsl:when test="$step ge $max-moves">
              <xsl:result-document href="#controls" method="ixsl:replace-content">
                Game over! Reload the HTML page for another game.
              </xsl:result-document>
            </xsl:when>
          </xsl:choose>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:if>
  </xsl:template>

  <xsl:function name="fi:neighboring-same-color-areas" as="element(*)*"><!-- result: fi:area* or area* -->
    <xsl:param name="color" as="xs:string" /><!-- don't read $area's @color because it doesn't yet carry its after-flooding value -->
    <xsl:param name="area" as="element(*)" />
    <xsl:param name="board" as="element(*)" />
    <xsl:if test="exists($board/*:area except $area)">
      <xsl:sequence select="fi:neighbors(
                              $area/*:square[not(@inside)], 
                              ($board/*:area except $area)/*:square[not(@inside)]
                            )/..[@color eq $color]" />
    </xsl:if>
  </xsl:function>

  <xsl:function name="fi:flood" as="element(*)">
    <xsl:param name="x" as="xs:integer" />
    <xsl:param name="y" as="xs:integer" />
    <xsl:param name="board" as="element(*)" />
    <xsl:param name="color" as="xs:string" />
    <xsl:variable name="area" select="$board/*:area[*:square[xs:integer(@x) eq $x and xs:integer(@y) eq $y]]" as="element(*)" />
    <xsl:variable name="joinme" select="$area union fi:neighboring-same-color-areas($color, $area, $board)" as="element(*)+" />
    <fi:board>
      <xsl:copy-of select="$board/@*" />
      <fi:area color="{$color}">
        <xsl:apply-templates select="$joinme/*:square[not(@inside)]" mode="flood"/>
        <xsl:sequence select="$joinme/*:square[@inside]"/>
      </fi:area>
      <xsl:sequence select="$board/*:area except ($joinme)" />
    </fi:board>
  </xsl:function>

  <xsl:function name="fi:neighborcount" as="xs:integer">
    <xsl:param name="x" as="xs:integer" />
    <xsl:param name="y" as="xs:integer" />
    <xsl:variable name="x-fringe-reduction" select="if (min(($x, $board-size - $x + 1)) eq 1) then 1 else 0" as="xs:integer" />
    <xsl:variable name="y-fringe-reduction" select="if (min(($y, $board-size - $y + 1)) eq 1) then 1 else 0" as="xs:integer" />
    <xsl:sequence select="4 - $x-fringe-reduction - $y-fringe-reduction" />
  </xsl:function>

  <xsl:template match="*:square[not(@inside)]" mode="flood">
    <xsl:copy>
      <xsl:copy-of select="@*" />
      <xsl:if test="count(fi:neighbors(., ../*:square)) eq xs:integer(@nc)">
        <xsl:attribute name="inside" select="'yes'" />
      </xsl:if>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="*:board" mode="render">
    <xsl:for-each select="ixsl:page()//*[@id eq 'hint']">
      <ixsl:set-attribute name="style:background-color" select="'transparent'" />
    </xsl:for-each>
    <xsl:result-document href="#board" method="ixsl:replace-content">
      <table>
        <tbody>
          <xsl:for-each-group select="fi:square union ./*:area/*:square" group-by="@y">
            <xsl:sort select="current-grouping-key()" data-type="number"/>
            <tr>
              <xsl:apply-templates select="current-group()" mode="#current">
                <xsl:sort select="@x" data-type="number"/>
              </xsl:apply-templates>
            </tr>
          </xsl:for-each-group>
        </tbody>
      </table>
    </xsl:result-document>
  </xsl:template>

  <xsl:template match="*:square" mode="render">
    <td style="background-color:{if (@color) then @color else ../@color}" data-coord="{@x}-{@y}">&#xfeff;</td>
  </xsl:template>

  <xsl:template match="@* | *" mode="flood group render">
    <xsl:copy>
      <xsl:apply-templates select="@* | node()" mode="#current"/>
    </xsl:copy>
  </xsl:template>

  <xsl:variable name="random-stmt" select="concat('Math.ceil(Math.random() * ', $num-colors, ')')" as="xs:string" />
  <xsl:function name="fi:rnd" as="xs:integer">
    <xsl:sequence select="ixsl:eval($random-stmt) cast as xs:integer"/>
  </xsl:function>

  <xsl:function name="fi:pow2" as="xs:integer">
    <xsl:param name="pow" as="xs:integer"/>
    <xsl:sequence select="if ($pow eq 0) then 2 else 2 * fi:pow2($pow - 1)"/>
  </xsl:function>

</xsl:stylesheet>