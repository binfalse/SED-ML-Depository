#!/bin/bash

die () { echo $1; exit 2; }

# dependencies
[ -x /bin/sed ] || die "cannot find sed"
[ -x /bin/cat ] || die "cannot find cat"
[ -x /usr/bin/curl ] || die "cannot find curl"
[ -x /usr/bin/perl ] || die "cannot find perl"
[ -x /usr/bin/xmllint ] || die "cannot find xmllint"
[ -x /usr/bin/zip ] || die "cannot find zip"
[ -x /usr/bin/unzip ] || die "cannot find unzip"
[ -x /usr/bin/find ] || die "cannot find find"
[ -x /bin/sleep ] || die "cannot find sleep"

ads[0]="http://sems.uni-rostock.de/"
ads[1]="http://binfalse.de/"
ads[2]="http://mbine.org/"
ads[3]="http://webcat.sems.uni-rostock.de/"
ads[4]="http://sed-ml.org/"
ads[5]="http://combinearchive.org/"
ads[6]="http://sysbioapps.dyndns.org/SED-ML_Web_Tools/Home/"
ads[7]="http://www.ebi.ac.uk/biomodels-main/"


for i in {001..583}
do
    model=BIOMD0000000$i
    modeldoc='http://www.ebi.ac.uk/biomodels-main/download?mid='$model
    if [ -e $model ]
    then
        echo "skipping $model as it already exists ..."
        continue
    fi

    echo "== processing model $model =="
    mkdir -p $model

    echo "downloading model ..."
    /usr/bin/curl -s $modeldoc > $model/$model.sbml

    echo "generating sedml script ..."
    /usr/bin/curl -s 'http://sysbioapps.dyndns.org/SED-ML_Web_Tools/Services/SedMLService.asmx/GetSedMLForSBMLUri?modeluri='$modeldoc'&initialTime=0&startTime=0&endTime=100&numPoints=1000&outputFloating=true&outputBoundary=false&outputCompartments=false&outputParameters=false&generatePlots=true&generateReport=true' | /usr/bin/xmllint --xpath "/node()/text()"  - | /usr/bin/perl -MHTML::Entities -ne 'print decode_entities($_)' > $model/$model.sedml

    echo "updating sedml script to refer to the downloaded model ..."
    /bin/sed -i.bak 's/"http[^"]*'$model'"/"'$model'.sbml"/' $model/$model.sedml && rm $model/$model.sedml.bak

    echo "creating combine archive ..."
    /bin/cat template-manifest | /bin/sed 's/MODEL/'$model'.sbml/' | /bin/sed 's/SIMULATION/'$model'.sedml/' > $model/manifest.xml
    cd $model
    /usr/bin/zip -qr combine-archive.omex * && rm manifest.xml
    cd -

    echo "simulating model and storing simulation results ..."
    /usr/bin/curl -sLF file=@$model/combine-archive.omex http://sysbioapps.dyndns.org/SED-ML_Web_Tools/Home/SimulatePostArchive > $model/simulation-results.omex
    
    echo "unpack simulation results ..."
		/usr/bin/unzip -q $model/simulation-results.omex -d $model/simulation-results && rm $model/simulation-results.omex
		rm $model/simulation-results/manifest.xml
		rm $model/simulation-results/model1.xml
		rm $model/simulation-results/simresults.xml
		
		echo "that's what was produced:"
		/usr/bin/find $model | /bin/sed 's/^/ > /' | /bin/sed 's/sedml/sedml\t <- this is your new SED-ML script/'
		
		
		echo -e "\nfeel free to take some time to study >>> "${ads[ $[ $RANDOM % ${#ads[@]} ] ]}" <<<\n\n"
		/bin/sleep 10
done


