<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet 
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:fi="http://fischer-imsieke.de/namespace/floodit"
  xmlns:ixsl="http://saxonica.com/ns/interactiveXSLT"
  xmlns:prop="http://saxonica.com/ns/html-property"
  extension-element-prefixes="ixsl"
  version="2.0"  
  exclude-result-prefixes="fi xs"
  >

  <xsl:param name="board-size" as="xs:integer" select="14" />
  <xsl:param name="max-moves" as="xs:integer" select="25" />
  <xsl:param name="num-colors" as="xs:integer" select="6" />


  <xsl:template name="main">
    <xsl:result-document href="#maxsteps" method="ixsl:replace-content">
      <xsl:value-of select="$max-moves"/>
    </xsl:result-document>
    <xsl:call-template name="step">
      <xsl:with-param name="count" select="0" />
    </xsl:call-template>
    <xsl:variable name="initial-board" as="element(fi:board)" select="fi:create-board($board-size, $num-colors)" />
    <xsl:apply-templates select="$initial-board" mode="render" />
    <xsl:apply-templates select="$initial-board" mode="group" />
    <xsl:call-template name="controls" />
  </xsl:template>

  <xsl:variable name="colors" as="xs:string+" 
    select="('#22f', '#f9b', '#ff3', '#f33', '#2b4', '#3ff', 'brown', 'purple', 'black', 'white', 'orange', 'gray')" />

  <xsl:template name="controls">
    <xsl:result-document href="#controls" method="ixsl:replace-content">
      <table>
        <tbody>
          <tr>
            <xsl:for-each select="$colors[position() le $num-colors]">
              <td id="{translate(., '#', '_')}" style="background-color:{.}">&#x2003;</td>
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
          <fi:square x="{$x}" y="{$y}" color="{$colors[$rnd]}" />
        </xsl:for-each>
      </xsl:for-each>
    </fi:board>
  </xsl:function>

  <xsl:template match="fi:board" mode="group">
    <xsl:result-document href="#rep" method="ixsl:replace-content">
      <xsl:copy>
        <xsl:copy-of select="@*" />
        <xsl:sequence select="fi:group-squares(fi:square[1], (), fi:square)" />
      </xsl:copy>
    </xsl:result-document>
  </xsl:template>

  <!-- xsl:iterate might come in handy here. Without it, some recursion is necessary. -->
  <xsl:function name="fi:group-squares" as="element(*)+"><!-- result: (fi:square | fi:area)* -->
    <xsl:param name="square" as="element(fi:square)*" />
    <xsl:param name="basket" as="element(*)*" />
    <xsl:param name="squares-and-areas" as="element(*)+" />

    <xsl:choose>
      <xsl:when test="exists($square)"><!-- there are ungrouped squares yet -->
        <!-- Neighbors of the same colour that are not already collected in the $basket: -->
        <xsl:variable name="neighbors" 
          select="fi:neighbors($square, $squares-and-areas/self::fi:square)
                    [@color = $square/@color]
                    [every $sq in $basket satisfies (not($sq is .))]" />
        <xsl:choose>
          <xsl:when test="exists($neighbors)">
            <xsl:sequence select="fi:group-squares($neighbors, ($square, $basket), $squares-and-areas)" />
          </xsl:when>
          <xsl:otherwise>
            <xsl:variable name="new-squares-and-areas" as="element(*)+">
              <fi:area color="{$square[1]/@color}">
                <xsl:apply-templates select="($basket union $square)" mode="group"/>
              </fi:area>
              <xsl:sequence select="$squares-and-areas except ($basket, $square)" />
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
    <xsl:param name="square" as="element(*)+" />
    <xsl:param name="squares" as="element(*)+" />
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
      <xsl:variable name="flooded" as="element(board)?">
        <!-- doesn't work: -->
        <!-- <xsl:apply-templates select="id('rep', ixsl:page())/*:board" mode="flood" > -->
        <xsl:apply-templates select="ixsl:page()//div[@id eq 'rep']/*:board" mode="flood">
          <xsl:with-param name="x" select="$x" />
          <xsl:with-param name="y" select="$y" />
          <xsl:with-param name="color" select="$color" />
        </xsl:apply-templates>
      </xsl:variable>
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

  <xsl:template match="*:board" mode="flood">
    <xsl:param name="x" as="xs:integer" />
    <xsl:param name="y" as="xs:integer" />
    <xsl:param name="color" as="xs:string" />
    <xsl:variable name="area" select="*:area[*:square[@x cast as xs:integer eq $x 
                                                      and 
                                                      @y cast as xs:integer eq $y]]" />
    <xsl:variable name="target-neighboring-areas" select="fi:neighbors($area/*:square, (*:area except $area)/*:square)/..[@color eq $color]" as="element(*)*" />
    <xsl:variable name="joinme" select="$area union $target-neighboring-areas" as="element(*)+" />
    <xsl:copy>
      <xsl:copy-of select="@*" />
      <fi:area color="{$color}">
        <xsl:sequence select="$joinme/*:square" />
      </fi:area>
      <xsl:sequence select="*:area except ($joinme)" />
    </xsl:copy>
  </xsl:template>

  <xsl:template match="*:board" mode="render">
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
    <td style="background-color:{if (@color) then @color else ../@color}" data-coord="{@x}-{@y}">
      &#x2003;
<!--       <xsl:value-of select="@x"/>-<xsl:value-of select="@y"/> -->
    </td>
  </xsl:template>

  <xsl:template match="@* | *" mode="#all">
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