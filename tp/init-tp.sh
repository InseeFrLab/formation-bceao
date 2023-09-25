#!/bin/sh

REPO_URL=https://github.com/InseeFrLab/formation-bceao.git
WORK_DIR=/home/onyxia/work
FORMATION_DIR=${WORK_DIR}/formation-bceao

# Clone the repository
git clone $REPO_URL $FORMATION_DIR
mc cp s3/projet-formation/diffusion/bceao/data_recensement_2017.csv $FORMATION_DIR/tp/data/data_recensement_2017.csv
chown -R onyxia:users $FORMATION_DIR

# Install dependencies
install2.r here

# Open the project
echo \
"
setHook('rstudio.sessionInit', function(newSession) {
 if (newSession)
  {
    rstudioapi::navigateToFile('tp/tp-manip-donnees-massives.qmd')
  }
}, action = 'append')

setHook('rstudio.sessionInit', function(newSession) {
  if (newSession && identical(getwd(), '${WORK_DIR}'))
  {
    message('Activation du projet RStudio')
    rstudioapi::openProject('${FORMATION_DIR}')
  }
}, action = 'append')
" >> /home/onyxia/.Rprofile
