> **Status (2026-11-06, D42).** Evidence for the trait relative neck length (D37); German original
> by Lucas, 5 November 2026. The reference ratios were recomputed from the listed Belyaev et al.
> Table S1 rows and all nine categories match `../species_traits_core.csv`. Not adopted from this
> document: the 0.5/0.5 weighting of body configuration and neck length (the primary distance uses
> equal weights, D37) and the sensitivity variants other than hedgehog `intermediate` (D38). The C7
> section is superseded by food acquisition and handling (D37).

# C6: Finale Kategorien der relativen Halslänge

Stand: 5. November 2026. Die Kodierung wird auf Lucas' ausdrücklichen Auftrag abschließend festgelegt; Unsicherheiten bleiben dokumentiert. Die Festlegung betrifft die Spezifikation für das Paper. Die Traitdateien und das R-Skript im Repository sind damit noch nicht aktualisiert; es wurde kein neues H3-Modell gerechnet.

## Abschließende Entscheidung

**C6 wird als grobes, ordinales anatomisches Merkmal beibehalten: relative Halslänge.** Es ersetzt inhaltlich den bisherigen „erwarteten Kopf-Hals-Beitrag zum Beschleunigungssignal“. Die Kategorien beschreiben Halsproportionen, keine gemessene Bewegung und keine Stärke des Sensorsignals. Ein hoher C6-Wert bedeutet daher nicht automatisch einen stärkeren Einfluss auf die Beschleunigung.

Das Referenzmaß ist `r = C/(T+L+S)`: Halswirbelsäule im Verhältnis zu Brustwirbelsäule, Lendenwirbelsäule und Kreuzbein. Für vorhandene vergleichbare Messungen werden adulte Individualquotienten gemittelt. Die vier folgenden Intervalle sind **eine hier festgelegte pragmatische Studienkonvention**, keine aus der Literatur übernommenen oder biologisch validierten Universalgrenzen. Sie wurden mit Kenntnis der anatomischen Referenzen und früherer H3-Ergebnisse festgelegt, ohne neue H3-Anpassung. Eine Präregistrierung wird nicht behauptet.

| Kategorie | Geordneter Code | Regel bei vorhandenem Referenzquotienten | Zugeordnete Taxa |
|---|---|---|---|
| Kurz | `short` / 1 | r < 0,30 | Igel; Waschbär |
| Mittel | `intermediate` / 2 | 0,30 ≤ r < 0,40 | Wisent; Rind; Hund; Rotfuchs |
| Lang | `long` / 3 | 0,40 ≤ r < 1,00 | Hauspferd; Przewalski-Pferd |
| Sehr lang | `very_long` / 4 | r ≥ 1,00 | Giraffe |

Neuer Spaltenname: `relative_neck_length_class`. Reihenfolge: `short < intermediate < long < very_long`. Die Gruppengrößen sind **2/4/2/1**. Die alten C6-Signalbeitragswerte sind als historischer Stand zu erhalten und dürfen nicht bloß unter dem alten Spaltennamen überschrieben werden.

Wo kein vollständiger Quotient vorliegt, ist eine begründete kategoriale Zuordnung möglich. Dabei bleibt der numerische Quotient fehlend und der Evidenztyp wird separat vermerkt. Das ist eine ausdrücklich kenntlich gemachte Ergänzung durch indirekte Evidenz bzw. Expertenurteil, keine Messwertimputation.

## Finale Zuordnung und Unsicherheiten

Die Unsicherheitsangaben beziehen sich auf die Übertragbarkeit der Kategorie auf das Studientaxon, nicht auf ein statistisches Konfidenzniveau. Quellen [1–9] und die Rohmaße stehen im nachfolgenden Rechercheteil.

| Taxon | Finale Kategorie | Evidenz | Dokumentierte Unsicherheit |
|---|---|---|---|
| Bison bonasus | Mittel | r = 0,347; ein adultes Skelett [1, 2] | Mittel: einzelne Literaturreferenz, keine Streuung für die Studienpopulation. |
| Bos taurus | Mittel | Mittel der zwei adulten Individualquotienten = 0,311 [1, 2] | Erhöht: Individualwerte 0,293 und 0,330 liegen auf beiden Seiten der Grenze 0,30. Alternative Kategorie für Sensitivität: kurz. |
| Canis lupus familiaris | Mittel | r = 0,366; ein adultes Skelett [1] | Erhöht: Rasse des Referenzpräparats nicht verifiziert; Hundepopulationen sind morphologisch heterogen. Kein Anspruch auf Gültigkeit für jede Rasse. |
| Equus caballus | Lang | r = 0,456; zwei adulte Skelette, beide > 0,40 [1, 3] | Mittel: sehr kleine Referenzstichprobe; keine vollständige Rassenvariation. |
| Equus ferus przewalskii | Lang | r = 0,428; zwei adulte Skelette, beide > 0,40 [1, 3] | Mittel: kleine Stichprobe; beide Werte liegen relativ nahe an 0,40. |
| Erinaceus europaeus | Kurz | Expertenzuordnung zur kurzen Halsproportion; absolute Halswirbelmaße als anatomischer Kontext [5, 7] | Hoch: kein verifizierter C/(T+L+S)-Wert. 19,73 mm absolute Halslänge beweisen für sich allein kein r < 0,30. Kategorie ist ein transparentes Expertenurteil; Alternative: mittel. |
| Giraffa camelopardalis | Sehr lang | Adult r = 1,183; auch die zwei juvenilen Referenzen liegen > 1 [1, 2] | Gering für die grobe Kategorie, trotz geringer Präparatezahl; kein präziser Populationsmittelwert behauptet. |
| Procyon lotor | Kurz | Indirekte obere Schranke aus Davis' Halsanteilen von 21–22 % der präsakralen Wirbelsäule [6] | Mittel: historische Messweise, nur Gattungsangabe in Tabelle 10 und unvollständige Angaben zu den vier Individuen. Kein exakter C/(T+L+S)-Wert übernommen. |
| Vulpes vulpes | Mittel | r = 0,373; ein adultes Skelett [1] | Mittel: kleine Referenzstichprobe; Abstand zur Grenze 0,40 ist begrenzt. |

**Warum der Waschbär jetzt kategorial zugeordnet werden kann:** Wenn die berichteten Anteile als vergleichbare Wirbelsäulenlängen interpretiert werden, ergibt selbst der höchste Halsanteil von 22 % einen Wert `C/(T+L) = 0,22/0,78 ≈ 0,2821`. Bei positiver Kreuzbeinlänge ist `C/(T+L+S)` kleiner. Damit stützen die Daten die Kategorie unter 0,30, obwohl sie keinen exakten kompatiblen Quotienten liefern. Diese Schrankenargumentation ist unsere Ableitung aus [6] und bleibt wegen der Mess- und Präparateunterschiede als indirekte Evidenz gekennzeichnet.

Beim Igel liegt keine entsprechende quantitative Schranke vor. Seine Zuordnung ist die schwächste Stelle der neuen Kodierung. Sie wird für die Arbeitsfassung festgelegt und nicht als empirisch bestätigte Grenzwertzuordnung dargestellt. Es wurde keine unabhängige Zweitkodierung durchgeführt.

## Distanzspezifikation und festgehaltene Robustheitsprüfungen

- C6 bleibt in der vorgesehenen Hauptdistanz. C3 und das neue C6 teilen sich wegen ihrer teilweise überlappenden Morphologieinformation ein Gesamtgewicht von 1: **C3 = 0,5; C6 = 0,5**. Andere für die betreffende Distanz freigegebene Merkmale behalten Gewicht 1. Diese Gewichtung ist eine nachvollziehbare Modellierungsentscheidung, kein statistisch nachgewiesenes Optimum; sie entfernt die Überschneidung nicht.
- C6 wird als geordneter Faktor behandelt. Abstände zwischen den vier Rangstufen sind eine Rechenkonvention der ordinalen Distanz und bedeuten keine gleich großen anatomischen oder signalphysikalischen Effekte.
- Für die Sensitivität werden Igel und Rind jeweils kurz/mittel variiert, einschließlich der gemeinsamen Alternativkodierung. Zusätzlich werden C3 allein und C6 allein mit Morphologie-Gesamtgewicht 1 sowie beide mit Gewicht 1 je Merkmal mit der festgelegten Hauptvariante verglichen. Ein Vergleich ohne C6 hält die übrigen Eingaben fest und ist entsprechend zu benennen.
- Da die Intervalle studienspezifisch sind, wird außerdem eine gröbere Zusammenfassung von mittel und lang geprüft. Unterschiede beim Giraffeneinfluss sind gesondert auszuweisen. Keine Variante wird wegen eines günstigeren H3-p-Werts ausgewählt.
- Diese Prüfungen sind festgehaltene nächste Analyseschritte, **noch keine ausgeführten Robustheitsergebnisse**. Insbesondere lässt sich aus dokumentierter Unsicherheit allein keine Robustheit der H3-Aussage ableiten.

**Kodierungsentscheidung abgeschlossen; Repositoriumsänderung und H3-Neuberechnung ausstehend.** Die Datenbasis besteht weiterhin aus sieben vollständigen Referenzquotienten, einer indirekt gestützten Kategorie und einem unsicheren Expertenurteil. Die Unvollständigkeit der kontinuierlichen Messreihe ist damit nicht verschwunden.

## Übergang zu C7: Nahrungsaufnahme und Nahrungserwerb

C7 heißt im Repository `dominant_feeding_foraging_mode` und ist bislang nominal kodiert. Die fünf vorhandenen Gruppen sind:

| Bestehende Gruppe | Aktuelle Zuordnung im Repository | Punkt für die Prüfung |
|---|---|---|
| `low_head_grazing` | Wisent, Rind, beide Pferdetaxa | Der Wisent ist je nach Umwelt ein Mischfresser mit erheblichem Gehölzanteil; die Gruppenbezeichnung passt nicht universell. |
| `ground_level_search_feeding` | Hund, Rotfuchs | Nahrungssuche und bereitgestelltes Futter auseinanderhalten; Haushund und freilebender Fuchs haben unterschiedliche Fütterungskontexte. |
| `high_browsing` | Giraffe | Typische Nahrungserwerbsweise von tatsächlicher Futterhöhe in den Aufnahmen trennen. |
| `ground_cover_search_probe` | Igel | Unterscheidung von sonstiger bodennaher Nahrungssuche braucht eine einheitliche Verhaltensregel. |
| `ground_tree_mixed_manipulative` | Waschbär | Aktive Vorderpfotenverwendung ist direkt belegt; „ground/tree“ beschreibt zusätzlich einen anderen Aspekt, die räumliche Nahrungssuche. |

Für die nächste C7-Entscheidung soll das Merkmal die **artspezifisch typische Weise des Nahrungserwerbs bzw. der Nahrungsaufnahme** beschreiben. Futterhöhe in einem konkreten Datensatz wäre ein separates Merkmal des Aufnahme-/Haltungskontexts. Die derzeitigen Bezeichnungen mischen Erwerbsbewegung, Höhe und Lebensraum. Die C7-Zuordnung ist in diesem Schritt deshalb noch nicht neu beschlossen.

Gezielt geprüfte Primärbelege:

- Kowalczyk et al. (2019), *Foraging plasticity allows a large herbivore to persist in a sheltering forest habitat: DNA metabarcoding diet analysis of the European bison*, Forest Ecology and Management, 449, 117474, [DOI](https://doi.org/10.1016/j.foreco.2019.117474): belegt flexible Nahrungszusammensetzung und wichtige Gehölzanteile für die untersuchte Waldpopulation. Die Sequenzanteile sind weder direkte Zeitanteile der Futtersuche noch Messungen der Kopfhaltung.
- Iwaniuk & Whishaw (1999), *How skilled are the skilled limb movements of the raccoon (Procyon lotor)?*, [PubMed](https://pubmed.ncbi.nlm.nih.gov/10512570/): Videoanalyse von Nahrungssuche, Greifen und Handhaben bei gehaltenen Waschbären; direkter Beleg für ausgeprägte Vorderpfotenverwendung, keine Validierung unserer gesamten C7-Gruppierung.
- Dimelow (1963), *Observations on the feeding of the hedgehog (Erinaceus europaeus L.)*, Proceedings of the Zoological Society of London, 141, 291–309, [DOI](https://doi.org/10.1111/j.1469-7998.1963.tb01614.x): Fütterungs- und Präferenzversuche an gehaltenen Igeln. Kontext für Nahrungserwerb; aus dem geprüften Abstract folgt keine quantifizierte Abgrenzung „search/probe“ gegenüber Hund oder Fuchs.

---

## Rechercheverlauf vor der abschließenden Kategorienentscheidung

Die folgenden Abschnitte erhalten die bisherige Recherche einschließlich der damals offenen kontinuierlichen Variante. Frühere Statusangaben und Entscheidungsvorschläge dokumentieren den Prüfverlauf; maßgeblich ist die oben festgelegte ordinale Kodierung. Insbesondere wird die frühere Forderung nach neun vollständigen Zahlenwerten durch eine ausdrücklich als solche dokumentierte kategoriale Expertenzuordnung ersetzt, nicht durch erfundene Messwerte.

## Ergebnis

Für sieben der neun Studientaxa liegen vergleichbare Skelettmaße vor. Sie stammen aus Tabelle S1 von Belyaev et al. (2024), die neben Carnivora auch Tabellenblätter mit den zuvor untersuchten Paarhufern und Unpaarhufern enthält. Für Waschbär und Europäischen Igel konnte in der geprüften Literatur kein passender Zahlenwert derselben Definition verifiziert werden. Das bedeutet eine Lücke dieser Recherche, nicht den Nachweis, dass solche Daten grundsätzlich fehlen.

Die anatomische Variante ist als neuer C6-Kandidat sinnvoll. Ihre Aufnahme in die Hauptdistanz ist noch nicht hinreichend vorbereitet: Zwei Taxa fehlen, die übrigen Referenzen beruhen auf wenigen Individuen, und C3 enthält bereits Halsproportionen.

Die gezielte Nachrecherche am selben Tag hat zusätzliche Messdaten für beide fehlenden Taxa erschlossen. Sie schließen die Lücke für `C/(T+L+S)` jedoch nicht: Für den Waschbären existieren ältere Anteile ohne Kreuzbein; für Waschbär und Igel liegen außerdem Halswirbellängen aus einer anderen Messreihe vor, deren Tabelle keine Rumpflängen enthält. Der Stand bleibt deshalb **7 von 9 Taxa mit vergleichbaren Quotienten**.

## Vorgeschlagene Definition

**Relative Halslänge = Länge der Halswirbelsäule / Länge von Brustwirbelsäule, Lendenwirbelsäule und Kreuzbein zusammen.**

Formel: `C / (T + L + S)`. Dimensionslos, kontinuierlich. Die Skelettabschnitte werden nach der Methode von Belyaev et al. an artikulierten Wirbelsäulen entlang der ventralen Sagittallinie gemessen; C reicht vom vorderen Rand des Atlas bis zum hinteren Rand von C7. [1–3]

Dieser Kandidat beschreibt Anatomie. Er misst weder die tatsächlich ausgeführte Bewegung noch den Beitrag zum Beschleunigungssignal. Der bisherige C6-Name und seine Stufen dürfen dafür nicht unverändert weiterverwendet werden. Ein möglicher neuer Spaltenname wäre `relative_neck_length`.

## Vorläufige Referenzwerte

Eigene Berechnung aus den Längen in Tabelle S1, Datei `JOA-244-205-s003.xlsx`, DOI 10.1111/joa.13955. Für diesen Vergleich wurden einheitlich nur als `ad` bezeichnete Individuen verwendet. Bei zwei Individuen ist der Wert das arithmetische Mittel der beiden individuellen Quotienten, nicht der Quotient gemittelter Längen. Diese Auswahl ist ein Vorschlag für die Referenzbildung, keine bereits akzeptierte Paperentscheidung.

| Studientaxon | n adulte Skelette | Referenzwert | Spannweite der Individualwerte | C3 derzeit |
|---|---:|---:|---:|---|
| Wisent – Bison bonasus | 1 | 0,347 | 0,347 | Rumpfbetont |
| Rind – Bos taurus | 2 | 0,311 | 0,293–0,330 | Rumpfbetont |
| Hund – Canis lupus familiaris | 1 | 0,366 | 0,366 | Allgemeiner Vierfüßerbau |
| Hauspferd – Equus caballus | 2 | 0,456 | 0,442–0,470 | Allgemeiner Vierfüßerbau |
| Przewalski-Pferd – Equus ferus przewalskii | 2 | 0,428 | 0,424–0,433 | Allgemeiner Vierfüßerbau |
| Europäischer Igel – Erinaceus europaeus | 0 | Offen | – | Kompakt/bodennah |
| Giraffe – Giraffa camelopardalis | 1 | 1,183 | 1,183 | Hochbeinig/langhalsig |
| Waschbär – Procyon lotor | 0 | Offen | – | Allgemeiner Vierfüßerbau |
| Rotfuchs – Vulpes vulpes | 1 | 0,373 | 0,373 | Allgemeiner Vierfüßerbau |

`n` bezeichnet Literaturpräparate, nicht Tiere aus den Beschleunigungsdatensätzen. Die drei Nachkommastellen dienen der Nachvollziehbarkeit und bedeuten keine entsprechende Genauigkeit eines Populationsmittels. Das Hauspferd heißt in der Quelle `Equus ferus caballus`.

## Nachrecherche zu Waschbär und Igel

### Waschbär: Verhältniszahl gefunden, Nenner abweichend

Davis (1964), gedruckte Seite 75, Tabelle 10, nennt für `Procyon` vier Individuen und folgende mittlere Anteile der Wirbelsäulenabschnitte: Hals 21,4 %, Brust 47,7 %, Lende 30,9 %. Die Spannweiten lauten 21–22 %, 47–48 % und 30–31,5 %. In Tabelle 9 auf derselben Seite wird `Procyon lotor` aufgeführt; die Zeile in Tabelle 10 nennt allerdings nur die Gattung, ohne die vier Individuen einzeln zu identifizieren. Die Tabelle wurde im Originalscan geprüft. [6]

Die drei Anteile summieren sich auf 100 % und schließen das Kreuzbein aus. Aus den publizierten Mittelanteilen lässt sich näherungsweise `21,4/(47,7+30,9) = 0,2723` für **C/(T+L)** ableiten. Das ist weder der gesuchte Quotient **C/(T+L+S)** noch ein aus individuellen Rohmaßen berechneter mittlerer Quotient. Die genaue Vergleichbarkeit der Messweise und die Altersauswahl sind ebenfalls nicht ausreichend belegt. **0,2723 wird deshalb nicht als fehlender C6-Wert eingesetzt.**

### Beide Taxa: absolute Halsmaße und konkrete Präparate identifiziert

Tabelle S3 zu Arnold et al. (2017) ist in der kumulativen Dissertation von Patrick Arnold zugänglich. Dort sind folgende Werte direkt überprüfbar; die Tabellenüberschrift gibt mm für Wirbel- und Tibialängen an. [5, 7]

| Taxon | Halswirbelsäule, mm | Tibia, mm | In Tabelle S2 gelistete Präparate |
|---|---:|---:|---|
| Procyon lotor | 51,57 | 91,72 | PMJ_Mam8037 |
| Erinaceus europaeus | 19,73 | 34,72 | PMJ_Mam74; ZMB_MAM_101380; ZMB_MAM_94010 |

Fundstellen: Tabelle S3 auf gedruckten Seiten 129 und 132 der Dissertation, PDF-Seiten 137 und 140. Die Halswirbel werden bei Arnold et al. einzeln ventral am Wirbelkörper gemessen; Atlas und Axis haben ausdrücklich definierte Messgrenzen. Die angegebenen Halslängen entsprechen der Summe der tabellierten Wirbelkörperlängen, abgesehen von Rundung. Bei mehreren Präparaten verwendet die Studie Artmittelwerte. Diese Daten wurden hier nicht erneut auf eine einheitliche Auswahl adulter Individuen reduziert.

T, L und S fehlen in dieser Tabelle. Auch `Halslänge/Tibia` wäre eine neue Definition, die zusätzlich Unterschiede der Gliedmaßenproportionen aufnimmt. Die absoluten Halsmaße werden daher weder mit allgemeinen Kopf-Rumpf-Längen noch mit Rumpfmaßen anderer Präparate zu scheinbar passenden Quotienten kombiniert. Die Präparatekennungen sind jedoch konkrete Anknüpfungspunkte, falls später vollständige, nach derselben Methode erhobene C-, T-, L- und S-Maße beschafft werden sollen. PMJ steht für Phyletisches Museum Jena, ZMB für Museum für Naturkunde Berlin. [5, 7]

### Weitere geprüfte Anknüpfungspunkte

Esteban et al. (2023) verwendeten einen CT-Scan des Waschbären `ZPB_PL_003`. Die betreffende Analyse untersucht Querschnittsflächen von Rücken- und Bauchmuskulatur; aus dem Methodenbericht ergibt sich kein unmittelbar übernehmbarer C/(T+L+S)-Wert. Der morphometrische Hauptdatensatz behandelt Wirbel von C3 bis zum letzten Lendenwirbel und liefert damit ebenfalls nicht automatisch vollständige Hals- und Kreuzbeinlängen. Eine neue Messung an zugänglichen Originalscans wäre zusätzliche Datenerhebung, kein bereits publizierter Ersatzwert. [8]

Die ergänzend geprüfte Netzwerkanalyse von Arnold et al. (2017) enthält den Europäischen Igel, verwendet Halsdaten aus derselben Längenstudie und berechnet relative Halslänge als Halslänge/Körpermasse^(1/3). Auch dieser Nenner entspricht nicht dem hier festgelegten Rumpfmaß. [9]

## Verhältnis zu C3 und zur Distanz

- **Zusätzliche Information:** C3 fasst beispielsweise Hund, Fuchs und beide Pferdeformen zusammen. Die gemessenen Halsquotienten unterscheiden sie innerhalb dieser Gruppe. Die neue Größe wäre deshalb nicht identisch mit C3.
- **Teilweise doppelte Gewichtung:** Bei der Giraffe steckt die Halsverlängerung bereits ausdrücklich in C3. Ein gleich gewichtetes zusätzliches Halsmerkmal würde diese anatomische Besonderheit nochmals berücksichtigen. Das ist eine Schlussfolgerung aus der bestehenden Kodierung, keine empirische Validierung eines besseren H3-Modells.
- **Giraffeneinfluss:** Unter den sieben vorläufigen Referenzwerten liegen die sechs übrigen Arten zwischen 0,311 und 0,456. Diese Spannweite beträgt nur 16,6 % der gesamten Spannweite einschließlich Giraffe. Bei einer einfachen Spannweitennormierung würde C6 daher vor allem Abstände zur Giraffe vergrößern. Die Aussage gilt nur für die sieben vorliegenden Taxa; es wurde keine vollständige Neun-Arten-Gower-Distanz berechnet.
- **Begrenzte Repräsentativität:** Pro Art stehen hier nur ein oder zwei adulte Präparate zur Verfügung. Insbesondere beim Hund ist ein einzelnes Präparat ohne verifizierte Rasse keine belastbare Abbildung der gesamten Rassenvariation. Auch Geschlecht, Alter, Haltung und die Herkunft der Präparate müssen in der Bewertung berücksichtigt werden.

### Konkreter Vorschlag für eine spätere Gewichtungsprüfung

Falls C6 für alle neun Taxa nach einer einheitlichen Definition ergänzt werden kann, lassen sich drei Varianten vorab festlegen. Alle anderen akzeptierten Merkmale behalten in diesem Vergleich dasselbe Gewicht; dieselben Arten und Transferpaare müssen in allen Varianten enthalten sein.

| Variante | Gewicht C3 | Gewicht neue C6-Halslänge | Zweck |
|---|---:|---:|---|
| A: Körperkonfiguration | 1 | 0 | Bestehende grobe Morphologiegruppen |
| B: Relative Halslänge | 0 | 1 | Ersatz durch das kontinuierliche anatomische Merkmal |
| C: Gemeinsame Morphologiegruppe | 0,5 | 0,5 | Beide Merkmale teilen sich das Gesamtgewicht 1 |

Variante C ist ein transparenter, eigener Gewichtungsvorschlag: Zwei teilweise überlappende Merkmale erhalten zusammen das Gewicht eines sonstigen Merkmals mit Gewicht 1. **Die Halbierung beseitigt keine Redundanz und ist kein empirisch nachgewiesenes optimales Gewicht.** Sie begrenzt lediglich den gemeinsamen Einfluss dieser beiden Morphologiemerkmale. Eine neue, ausdrücklich halsunabhängige Definition von C3 wäre ein anderer Ansatz und müsste separat begründet und neu kodiert werden.

Die Varianten sind anhand der paarweisen Distanzen und der Stabilität der H3-Schätzung zu vergleichen; sinnvoll ist zusätzlich eine getrennt gekennzeichnete Prüfung des Giraffeneinflusses. Unterschiede im H3-p-Wert sind kein Auswahlkriterium für die Definition. Solange zwei Quotienten fehlen, liegt hier ein Prüfplan und kein Ergebnis einer solchen Sensitivitätsanalyse vor. Eine Untersuchung nur der sieben verfügbaren Taxa wäre als eigener, eingeschränkter Vergleich auszuweisen und dürfte nicht mit der vollständigen Neun-Taxa-Analyse gleichgesetzt werden.

## Entscheidungsvorschlag

1. Relative Halslänge als ausdrücklich neu definierten, kontinuierlichen C6-Kandidaten festhalten.
2. Vor einer Hauptanalyse dieselben anatomischen Maße für Waschbär und Igel ergänzen; fehlende Werte nicht durch „niedrig“, Null oder unmarkierte Werte verwandter Arten ersetzen.
3. Bei ausreichender Abdeckung die gemeinsame Gewichtung mit C3 begründen und die Varianten mit C3, mit Halslänge und mit beiden vergleichen. Die Traitentscheidung anhand Definition und Evidenz treffen; einen günstigeren H3-p-Wert nicht als Auswahlkriterium verwenden.

Falls die beiden Lücken nicht mit vertretbarem Aufwand geschlossen werden, die Ersatzvariable vorerst nicht in die vollständige Neun-Arten-Hauptdistanz aufnehmen. Der bisherige erwartete Signalbeitrag bleibt ein getrennt zu beurteilender explorativer Kandidat. Aus diesem Bericht folgt keine automatische Änderung oder Streichung im Repository.

## Nachvollziehbarkeit der Zahlen

Alle Längen in mm. Spalten M–P der Originaldatei enthalten C, T, L und S. Zeilennummern beziehen sich auf die Originalarbeitsblätter. [1–3]

| Blatt / Zeile | Präparat | Taxon | C | T | L | S |
|---|---|---|---:|---:|---:|---:|
| Material / 39 | ZMMU S-102093 | Hund | 192 | 284 | 203 | 37 |
| Material / 51 | ZMMU S-113114 | Fuchs | 132 | 185 | 145 | 24 |
| Artiodactyla / 23 | ZMMU S-175340 | Giraffe | 1485 | 775 | 280 | 200 |
| Artiodactyla / 34 | ZMMU S-193088 | Wisent | 540 | 940 | 360 | 255 |
| Artiodactyla / 36 | ZMMU S-102026 | Rind | 380 | 705 | 365 | 227 |
| Artiodactyla / 37 | IEE 1932 | Rind | 435 | 735 | 390 | 195 |
| Perissodactyla / 18 | ZMMU S-102019 | Hauspferd | 590 | 785 | 290 | 180 |
| Perissodactyla / 19 | ZMMU S-106944 | Hauspferd | 323 | 470 | 156 | 105 |
| Perissodactyla / 29 | ZMMU S-158572 | Przewalski-Pferd | 490 | 730 | 255 | 147 |
| Perissodactyla / 30 | ZMMU S-187005 | Przewalski-Pferd | 494 | 720 | 255 | 190 |

Zwei weitere Giraffenpräparate sind als juvenil markiert und nicht im adulten Referenzwert enthalten. In `Artiodactyla`, Zeile 24, stehen C = 1075 und der gemeinsame Rumpfwert T+L+S = 905 in zusammengeführten Zellen N:P; daraus folgt 1,187845. Dieser Gesamtwert darf nicht dreimal addiert werden. Zeile 25 ergibt 960/(610+174+120) = 1,061947. Zusammen mit dem adulten Präparat stimmen diese Werte mit der publizierten Giraffenspannweite von etwa 106,19–118,78 % überein. [2]

## Quellen und Abgrenzungen

1. Belyaev, R. I., et al. (2024). *Running, jumping, hunting, and scavenging: Functional analysis of vertebral mobility and backbone properties in carnivorans*. Journal of Anatomy, 244, 205–231. [DOI 10.1111/joa.13955](https://doi.org/10.1111/joa.13955). [Volltext und Tabelle S1](https://pmc.ncbi.nlm.nih.gov/articles/PMC10780164/). Daten wurden aus dem veröffentlichten Supplement abgerufen: `JOA-244-205-s003.xlsx`. Die Datei enthält die Blätter `Material`, `Artiodactyla` und `Perissodactyla`. [Öffentliches Supplementpaket](https://www.ebi.ac.uk/europepmc/webservices/rest/PMC10780164/supplementaryFiles?includeInlineImage=false).
2. Belyaev, R. I., Kuznetsov, A. N., & Prilepskaya, N. E. (2021). *How the even-toed ungulate vertebral column works: Comparison of intervertebral mobility in 33 genera*. Journal of Anatomy, 239, 1370–1399. [DOI 10.1111/joa.13521](https://doi.org/10.1111/joa.13521).
3. Belyaev, R. I., Kuznetsov, A. N., & Prilepskaya, N. E. (2023). *Truly dorsostable runners: Vertebral mobility in rhinoceroses, tapirs, and horses*. Journal of Anatomy, 242, 568–591. [DOI 10.1111/joa.13799](https://doi.org/10.1111/joa.13799).
4. Loscher, D. M., et al. (2016). *Timing of head movements is consistent with energy minimization in walking ungulates*. Proceedings of the Royal Society B, 283, 20161908. [DOI 10.1098/rspb.2016.1908](https://doi.org/10.1098/rspb.2016.1908). Deren Quotient wird anhand äußerer Landmarken in Videoaufnahmen bestimmt und ist nicht ungeprüft mit dem Skelettmaß C/(T+L+S) austauschbar.
5. Arnold, P., Amson, E., & Fischer, M. S. (2017). *Differential scaling patterns of vertebrae and the evolution of neck length in mammals*. Evolution, 71, 1587–1599. [DOI 10.1111/evo.13232](https://doi.org/10.1111/evo.13232). Das in Quelle 7 eingesehene Supplement enthält Halswirbel-, Tibia- und Körpermassendaten; es liefert damit nicht den hier benötigten Rumpfnenner. Es wurde kein Ersatzquotient für Igel oder Waschbär daraus übernommen.
6. Davis, D. D. (1964). *The giant panda: A morphological study of evolutionary mechanisms*. Fieldiana: Zoology Memoirs, 3. Chicago Natural History Museum. Tabelle 10, S. 75, sowie Tabelle 9 auf derselben Seite. [Digitalisiertes Original](https://libsysdigi.library.uiuc.edu/OCA/Books2010-10/giantpandamorpho03davi/giantpandamorpho03davi.pdf), PDF-Seite 87. Zahlen im Scan visuell geprüft; Publikationsdatum auf dem Titelblatt: 7. Dezember 1964.
7. Arnold, P. (2018). *On the evolutionary morphology of the mammalian neck: Disparity and constraints*. Dissertation, Friedrich-Schiller-Universität Jena; Disputation 9. April 2018. [Volltext einschließlich Supplement zu Quelle 5](https://www.db-thueringen.de/servlets/MCRFileNodeServlet/dbt_derivate_00041290/dissarnold.pdf). Tabelle S2: Präparateliste; Tabelle S3: Halswirbel-, Tibia- und Körpermassendaten, S. 127–139. Die zwei hier genannten Datenzeilen wurden im PDF visuell geprüft.
8. Esteban, J. M., et al. (2023). *The impact of the land-to-sea transition on evolutionary integration and modularity of the pinniped backbone*. Communications Biology, 6, 1141. [DOI 10.1038/s42003-023-05512-8](https://doi.org/10.1038/s42003-023-05512-8). [Volltext](https://pmc.ncbi.nlm.nih.gov/articles/PMC10638317/). Methoden und Datenverfügbarkeit geprüft; kein vollständiger Hals-Rumpf-Quotient daraus abgeleitet.
9. Arnold, P., et al. (2017). *Musculoskeletal networks reveal topological disparity in mammalian neck evolution*. BMC Evolutionary Biology, 17, 251. [DOI 10.1186/s12862-017-1101-1](https://doi.org/10.1186/s12862-017-1101-1). [Volltext](https://pmc.ncbi.nlm.nih.gov/articles/PMC5729486/). Relative Halslänge wird dort über Körpermasse^(1/3) normiert; keine mit C/(T+L+S) identische Definition.

Repositorybezug: [C3-Review](https://github.com/ELBE223/paper-izw-cross-species-transfer/blob/a2b68b1cc4e16e6334398758c56882ce232e7508/00_documentation/trait_body_configuration_review.md) und [Core-Traits](https://github.com/ELBE223/paper-izw-cross-species-transfer/blob/a2b68b1cc4e16e6334398758c56882ce232e7508/00_documentation/species_traits_core_h3_final.csv), geprüft am 5. November 2026, Commit `a2b68b1cc4e16e6334398758c56882ce232e7508`.
