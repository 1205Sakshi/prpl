######################################################################################################
usage() {
  echo "Usage init_go_library.bash --library LIBRARY [--uri GIT_URI] [--name RECIPE_NAME] [--srcrev LIBRARY_VERSION] [--srcbranch LIBRARY_BRANCH]"
}

helper()
{
echo "Objective is to initialize a recipe  whit devtool and to adapt to golang."
echo "params are :"
echo "  --library (required) : name of the library (corresponding to the module name, see go.mod)"
echo "  --uri : URI used to extract and create the source (with or without prefix git:// and suffix .git) if not set, --library value will be choosen"
echo "  --name : Name of the recipe. If not set it will be uri with '/' replaced by '-'"
echo "  --srcrev : git repo tag"
echo "  --srcbranch : git repo branch"
}

CMD="$0 $*"
LIBRARY="";GIT_URI="";RECIPE_NAME="";VERSION_OPTION="";BRANCH_OPTION=""
while [ "$1" != "" ]; do
  case $1 in
    --library )   shift
                  LIBRARY=$1
                  ;;
    --uri )       shift
                  GIT_URI=$1
                  ;;
    --name )      shift
                  RECIPE_NAME=$1
                  ;;
    --srcrev )    shift
                  VERSION_OPTION="--srcrev $1"
                  ;;
    --srcbranch ) shift
                  BRANCH_OPTION="--srcbranch $1"
                  ;;
    -h | --help ) usage
                  helper
                  exit
                  ;;
    * )           usage
                  exit 1
  esac
  shift
done
if [ x${LIBRARY} == "x" ];then
  usage
  exit 1
fi
if [ x${GIT_URI} == "x" ];then
  GIT_URI=${LIBRARY}
fi
GIT_URI=$(echo "${GIT_URI}" | sed 's%^git://%%' | sed 's%.git$%%')
if [ x${RECIPE_NAME} == "x" ];then
  RECIPE_NAME=$(echo "${LIBRARY}" | sed 's%/%-%g')
fi
echo "$(date "+%Y/%m/%d - %H:%m:%S") --- $*" | tee -a ${LOG_FILE}
LOG_FILE=/sdkworkdir/workspace/work/${RECIPE_NAME}.log
DPD_FILE=/sdkworkdir/workspace/work/${RECIPE_NAME}_depends.txt
mkdir -p /sdkworkdir/workspace/work/sources
echo "######################################################################################################" | tee -a ${LOG_FILE}
echo "$(date "+%Y/%m/%d - %H:%m:%S") : CMD = $CMD" | tee -a ${LOG_FILE}
echo "######################################################################################################" | tee -a ${LOG_FILE}
echo "On going cmd : devtool add ${RECIPE_NAME} --no-same-dir git://${GIT_URI} ${VERSION_OPTION} ${BRANCH_OPTION}"  | tee -a ${LOG_FILE}
devtool add ${RECIPE_NAME} git://${GIT_URI} --no-same-dir ${VERSION_OPTION} ${BRANCH_OPTION} | tee -a ${LOG_FILE}
if [ $? -ne 0 ];then
  echo "Error on cmd devtool add ${RECIPE_NAME} git://${GIT_URI} --no-same-dir ${VERSION_OPTION} ${BRANCH_OPTION}" | tee -a ${LOG_FILE}
  exit 1
fi
rm -rf /sdkworkdir/workspace/work/sources/${RECIPE_NAME}
mv /sdkworkdir/workspace/sources/${RECIPE_NAME} /sdkworkdir/workspace/work/sources
if [ $? -ne 0 ];then
  echo "Error on cmd mv /sdkworkdir/workspace/sources/${RECIPE_NAME} /sdkworkdir/workspace/work/sources" | tee -a ${LOG_FILE}
  exit 1
fi
mkdir -p $(dirname /sdkworkdir/workspace/sources/${RECIPE_NAME}/src/${LIBRARY})
ln -s /sdkworkdir/workspace/work/sources/${RECIPE_NAME} /sdkworkdir/workspace/sources/${RECIPE_NAME}/src/${LIBRARY}
if [ $? -ne 0 ];then
  echo "Error on cmd ln -s /sdkworkdir/workspace/work/sources/${RECIPE_NAME} /sdkworkdir/workspace/sources/${RECIPE_NAME}/src/${LIBRARY}" | tee -a ${LOG_FILE}
  exit 1
fi
RECIPE_FILE=/sdkworkdir/workspace/recipes/${RECIPE_NAME}/${RECIPE_NAME}_git.bb
cp ${RECIPE_FILE} /sdkworkdir/workspace/work
if [ $? -ne 0 ];then
  echo "Error on cmd cp ${RECIPE_FILE} /sdkworkdir/workspace/work" | tee -a ${LOG_FILE}
  exit 1
fi
egrep -v "^#|^$|^PV =|^S =" /sdkworkdir/workspace/work/${RECIPE_NAME}_git.bb  | sed '/^do_configure/,$d' > ${RECIPE_FILE}

sed -i 's%file://%file://src/${GO_IMPORT}/%' ${RECIPE_FILE}
if [ $? -ne 0 ];then
  echo "Error on cmd sed -i 's%file://%file://src/${GO_IMPORT}/%' ${RECIPE_FILE}" | tee -a ${LOG_FILE}
  exit 1
fi
if [ -r /sdkworkdir/workspace/sources/${RECIPE_NAME}/src/${LIBRARY}/go.mod 2>/dev/null ];then
  GO_MODULE=$(grep "^[ ]*module" /sdkworkdir/workspace/sources/${RECIPE_NAME}/src/${LIBRARY}/go.mod | awk '{print $2}')
else
  GO_MODULE=${LIBRARY}
fi
echo GO_IMPORT = '"'${GO_MODULE}'"' >> ${RECIPE_FILE}
echo GO_INSTALL = '"${GO_IMPORT}"' >> ${RECIPE_FILE}
echo GO_WORKDIR = '"${GO_IMPORT}"' >> ${RECIPE_FILE}
printf 'export GO111MODULE="off"\n\n' >> ${RECIPE_FILE}

printf '# -- DEPENDS BEGIN\n\nRDEPENDS:${PN} += " \\\nbash \\\n"\nRDEPENDS:${PN}-dev += " \\\nbash \\\n"\n' >> ${RECIPE_FILE}
printf 'inherit go\n\n' >> ${RECIPE_FILE}
printf 'CGO_CFLAGS += "-I${WORKDIR}/recipe-sysroot/usr/include"\n\n' >> ${RECIPE_FILE}

if [ -r /sdkworkdir/workspace/sources/${RECIPE_NAME}/src/${LIBRARY}/go.mod 2>/dev/null ];then
  sed -n '/require[ ]*(/,/)/{/require[ ]*(/!{/)/!p}}' /sdkworkdir/workspace/sources/${RECIPE_NAME}/src/${LIBRARY}/go.mod | awk '{print $1":"$2}' > ${DPD_FILE}
  grep require /sdkworkdir/workspace/sources/${RECIPE_NAME}/src/${LIBRARY}/go.mod | grep -v "require[ ]*(" | sed 's%require %%' | awk '{print $1":"$2}' >> ${DPD_FILE}
fi

printf 'init_go_library.bash done.\nresume :\n'  | tee -a ${LOG_FILE}
echo "RECIPE_NAME = ${RECIPE_NAME}" | tee -a ${LOG_FILE}
echo "LIBRARY = ${LIBRARY}" | tee -a ${LOG_FILE}
echo "GIT_URI = ${GIT_URI}" | tee -a ${LOG_FILE}
echo "GO_MODULE = ${GO_MODULE}" | tee -a ${LOG_FILE}
echo "recipe = ${RECIPE_FILE}" | tee -a ${LOG_FILE}
if [ $(cat ${DPD_FILE} | wc -l) -lt 1 ];then
  echo "There are no dependencies" | tee -a ${LOG_FILE}
else
  echo "There are dependencies (see file ${DPD_FILE}" | tee -a ${LOG_FILE}
  echo "for each one, you 'll (probably) need to create its recipe. Maybe it'll required some adaptation (for example on branch if master is not used or git url if it differs from library) :" | tee -a ${LOG_FILE}
  awk -F: '{print "./init_go_library.bash --library "$1" --srcrev "$2}' ${DPD_FILE} | tee -a ${LOG_FILE}
  echo "this will generate also recipes that need to be built (you'll need to take into account the previous adaptations) :" | tee -a ${LOG_FILE}
  echo "you 'll also need to add dependencies in recipe (again (you'll need to take into account the previous adaptations) :" | tee -a ${LOG_FILE}
  sed 's%/%-%g' ${DPD_FILE} | awk -F: -v recipename=${RECIPE_NAME} '{print "./add_go_dependency.bash --name "recipename" --dep "$1}' | tee -a ${LOG_FILE}
fi
echo "Then you can try a :" | tee -a ${LOG_FILE}
echo "devtool build-image -p ${RECIPE_NAME}" | tee -a ${LOG_FILE}
echo "######################################################################################################" | tee -a ${LOG_FILE}
echo "log duplicated in file ${LOG_FILE}"
###
