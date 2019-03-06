# Linguaggio Sorgente (LS)
## Struttura file sorgente
Un programma in **LS** è contenuto in un singolo file con questa struttura:
1. Parte iniziale con tutte le dichiarazioni di tipo. Nuovi tipi possono
essere dichiarati solo in questa porzione del file.
2. Parte con tutte le definizioni di variabili globali.
3. Parte con tutte le definizioni di funzione.
4. Parte finale con la funzione d’ingresso al programma chiamata start.
## Tipi
Un programma in LS ha i seguenti tipi.
1. Tipi base: interi ```integer```, booleani ```boolean``` (le costanti booleane
sono ```true``` e ```false```), virgola mobile ```floating```, caratteri ```char```, stringhe
```string```.
2. Tipi custom: ovvero nomi di tipo definiti dall’utente (tramite dichiarazione
nella parte iniziale del file sorgente).
Un programma in **LS** ha i seguenti costruttori di tipo
1. Array multidimensionali: ```array(t,n1,n2,...)```, dove ```t``` è un tipo e ```n1, n2``` 
ecc sono interi che danno le dimensioni dell’array.
2. Record: ```record(t1 f1, t2 f2,...)``` dove ```ti``` è un tipo e ```fi``` è il
corrispondente nome di campo.
*I costruttori di tipo possono essere utilizzati sono nelle dichiarazioni di tipo.*

Due tipi sono equivalenti se 1) o sono lo stesso tipo di base 2) o sono lo
stesso tipo custom. Quindi due tipi custom con due nomi differenti sono
sempre *diversi*, anche se sono definiti nello stesso modo (pertanto nel type
checking non c’è bisogno di verificare la struttura di due tipi).

## Dichiarazioni di tipo e di variabile

1. Per dichiarare un nuovo tipo t:
```newtype t c;```
dove ```c``` è un costruttore di tipo.
Come da definizione, dentro un costruttore di tipo si possono usare
solo tipi e non costruttori di tipo in maniera annidata. Ad esempio
per dichiarare un tipo record che ha un campo che è un array prima
bisogna dichiarare il tipo array per il campo e poi il tipo record:
    ```
    newtype campo1 array(integer,10,20);
    newtype tipo record(campo1 f1, integer f2);
    ```
    Ogni tipo dichiarato è visibile a tutti gli altri indipendentemente dall’ordine
    di dichiarazione. Quindi le dichiarazioni di tipo possono essere ricor-
    sive (o più in generale mutuamente ricorsive):
    ```
    newtype tipo1 record(integer f1, tipo1 f2)
    ```
    Ogni tipo *custom* ```t``` usato dentro un costruttore di tipo è da consid-
    erarsi come un *riferimento al tipo* ```t```, in maniera analoga a quello che
    fa *Java* dove ogni variabile o campo di tipo oggetto è in realtà un
    riferimento.
2. Per dichiarare una serie di nuove variabili di tipo t:
    ```
    newvars t v1,...;
    ```
    Se il tipo ```t``` dell’esempio sopra è un tipo di base allora lo spazio nec-
    essario per ```v1``` ecc è effettivamente allocato. Se invece ```t``` è un tipo
    custom allora ```v1``` è da considerarsi una variabile riferimento al tipo
    ```t``` in maniera simile a *Java*. Al contrario delle definizioni di tipo, le
    definizioni di variabili possono anche essere locali ad una funzione.

## new e free
Dopo che una variabile ```v``` di un tipo custom ```t``` è stata dichiarata, lo spazio
necessario dovrà essere allocato esplicitamente, e successivamente deallo-
cato:
```
...
newvars t v;
...
v=new(t);
...
free(v);
```
Stessa cosa vale per i campi di tipi custom di un record.

## Funzioni
Le funzioni vengono dichiarate nella parte apposita del file di sorgente nella
seguente maniera:
```
func foo(t1 p1, t2 p2,....):t
begin
......
end
```
La funzione ```foo``` restituisce un valore di tipo ```t``` e accetta parametri ```p1``` di tipo
```t1``` ecc. Se la funzione non restituisce un valore allora ```t``` deve essere il tipo
speciale ```null```. La lista parametri può essere vuota.
```
func foo():integer
begin
...
end
func foo(integer i):null
begin
...
end
```
Le dichiarazioni di variabili locali devono apparire tutte insieme e subito
dopo il ```begin```. Se la funzione ha un tipo di restituzione diverso da ```null```
allora nel corpo deve esserci almeno un ```return``` e dove e dev’essere del tipo
appropriato.
Ogni funzione dichiarata è visibile a tutte le altre indipendentemente
dall’ordine di dichiarazione. Quindi le funzioni possono essere ricorsive (o più
in generale mutuamente ricorsive): l’invocazione di una funzione è l’usuale
```foo(e1,e2,...)```.
Per la funzione ```start``` si applica la stessa sintassi:
```
func start(t1 p1, t2 p2...):t
begin
...
end
```
Esistono due vincoli extra per ```start```:
1. i tipi dei parametri possono essere solo tipi base, dato che sono passati
all’eseguibile dalla linea di comando
2. il tipo di restituzione può essere solo null o integer.

## Identificatori
Gli identificatori, siano essi nomi di variabili, di tipi custom o di funzioni,
hanno la seguente definizione: sequenze di caratteri che possono essere let-
tere maiuscole o minuscole, cifre o underscore _ e il cui primo simbolo è
sempre una lettera.

## Assegnamento
L’operatore di assegnamento è =. Al contrario del C, non può apparire
dentro espressioni. Analogamente a Java, l’assegnamento causa aliasing per
3i tipi custom. Ovvero se ```x,y``` sono di tipo custom ```t``` allora ```x=y``` non *”copia”*
i dati riferiti da ```y``` ma assegna ad ```x``` solamente il riferimento a tali dati.

## Espressioni numeriche
Soliti operatori normali +,-,\*,/ (il - è anche unario). Ovviamente variabili e
chiamate di funzione possono apparire all’interno di espressioni. Conversioni
fra ```floating``` e ```integer``` *non sono mai fatte implicitamente dal compilatore*.
L’unica conversione possibile è da integer a floating e deve essere fatta *esplicitamente*
dall’utente chiamando ```floating(e1)``` dove ```e1``` è un’espressione
di tipo intero.

## Espressioni booleane
Soliti operatori relazionali fra ```interi``` e ```floating```: <,>,<=,>=,==,!=. Anche
per queste espressioni vale la regola per le conversioni da ```interi``` a ```floating```
vista sopra. Soliti operatori booleani: ||,&&,!. Le predecenze sono le stesse
del **C**.

## Blocchi
Come anticipato per la definizione di funzioni, i delimitatori di blocco sono
begin e end e ovviamente si applicano anche a tutti gli statement di controllo
di flusso. A parte l’eccezione delle variabili locali di una funzione, *non è
possibile dichiarare variabili locali ad un blocco* e quindi i blocchi non possono
apparire da soli (sarebbero inutili) ma solo *”agganciati”* a dichiarazioni di
funzioni e statement di controllo di flusso.

## Accesso array e record
Esempio di accesso ad array multidimensionale: ```A[i1,i2,i3]```. Esempio di
accesso al campo ```c1``` di un record: ```R.c1```.

## Loop
Esiste solo il loop generico (niente ciclo for):
```
loop(B)
begin
...
end
```
dove ```B``` è un espressione booleana. ```Begin``` e ```end``` sono obbligatori anche se il
corpo è un solo statement. ```Begin``` e ```end``` possono stare anche sulla stessa riga
del loop.

## If-then-else
Il ramo else è opzionale:
if(B)
then
begin
...
end
else
begin
...
end
Begin e end sono **obbligatori** anche se i corpi sono un solo statement. Then,
else e i rispettivi begin e end possono stare anche sulla stessa riga dell’if.

## Terminazione
Alla fine di qualsiasi statement che non sia un *loop* o un *if-then-else* ci deve
essere un ; di terminazione. Stessa cosa vale per le dichiarazioni di variabili
e di tipi (ma ovviamene non per le dichiarazioni di funzioni, che hanno il
blocco begin-end).

## Operatore di assegnamento lazy
L’operatore di assegnamento lazy ```?=``` viene applicato come l’assegnamento
normale ad una qualsiasi espressione: ```v?=e```. Con il normale assegnamento
```v=e``` l’espressione ```e``` verrebbe valutata subito ed il suo valore verrebbe asseg-
nato a ```v```. Nel caso lazy ```v?=e``` la valutazione non viene effettuata subito ma
viene rimandata al momento in cui ```v``` verrà effettivamente utilizzata. Ad
esempio
```
...
v?=i+j*fib(g);
...
if(p>0)
then
begin
c=v+1
end
```
In questo caso l’espressione ```i+j\*fib(g)``` (dove ```fib``` è la funzione di fibonacci
ad esempio) non viene valutata al momento dell’assegnamento lazy a ```v```.
Invece verrà valutata se e quando nel seguito del codice verrà fatto effetti-
vamente uso della variabile ```v``` ovvero, in questo esempio, solo se nell’```if``` alla
fine il ramo ```then``` verrà eseguito. Nel caso in cui ```v``` venga usato e quindi
l’espressione venga valutata, i valori delle variabili contenuti nell’espressione
dovranno essere quelli presenti al momento dell’assegnamento lazy e non i
valori presenti al momento dell’effettivo uso di ```v```. Quindi, in questo esem-
pio, quando ```v``` viene usata nel ramo ```then```, per valutare ```i+j*fib(g);``` i valori
delle variabili ```i,j,g``` devono essere quelli presenti al momento dell’istruzione
```v?=i+j*fib(g);```.

## Input/output
Le funzioni di input/output sono di ”comodo” e sono esattamente la ```printf```
e la ```scanf``` del **C**. Hanno esattamente la stessa sintassi che non viene
parsata del compilatore **LS**. Queste due funzioni vengono solamente
”tradotte” direttamente in C. Gli unici controlli che vengono fatti dal
compilatore del LS sono i seguenti:
1. che il primo parametro di printf/scanf sia di tipo string
2. che i successivi parametri non contengano errori relativi al linguag-
gio LS ovvero che siano espressioni corrette sia sintatticamente che
semanticamente.

## Linguaggio Destinazione
Il linguaggio destinazione è il C, completo e senza limitazioni.

## Note
1. Il compilatore LS effettua tutti i controlli sintattici (a parte
quelli relativi a printf/scanf). Ovvero il compilatore C a cui verrà poi
passato il codice risultato della compilazione non dovà dare errori di
sintassi (a parte eventuali errori di sintassi relativi a printf/scanf).
2. Il compilatore LS dovrà effetuare tutti i normali controlli semantici:
controlli di tipo; controlli che variabili, tipi custom e funzioni usate
siano state dichiarate; controlli sulle invocazioni delle funzioni (numero
e tipi di parametri); ecc.
