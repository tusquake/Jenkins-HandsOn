# Jenkins Fundamentals: CI/CD Pipelines from Theory to Practice on GCP

> **A hands-on, end-to-end record of learning Jenkins: first the theory (with real-world analogies), then a practical lab on a Google Cloud VM covering installation, Freestyle jobs, Declarative Pipelines, artifact archiving, credentials binding, and Multibranch Pipelines. Everything created in the lab is destroyed at the end so a company account incurs no ongoing cost.**

This repository documents my Jenkins learning journey. It covers **core theory**, the **exact commands and pipelines I ran**, the **errors I hit and how I fixed them**, a **Jenkins vs. GitHub Actions comparison**, a **production hardening roadmap**, and a **DevOps interview guide**.

---

## Table of Contents

1. [Overview and Tech Stack](#overview-and-tech-stack)
2. [CI/CD Foundations](#cicd-foundations)
3. [Jenkins Core Theory](#jenkins-core-theory)
4. [Jenkins vs. GitHub Actions and Other Tools](#jenkins-vs-github-actions-and-other-tools)
5. [Practical Lab on GCP](#practical-lab-on-gcp)
6. [Real-World Troubleshooting](#real-world-troubleshooting--errors-faced)
7. [Beyond the Lab: Production Roadmap](#beyond-the-lab-production-roadmap)
8. [DevOps Interview Guide](#devops-interview-guide)
9. [Teardown and Cost Optimization](#teardown-and-cost-optimization)
10. [Security Notes](#security-notes)

---

## Overview and Tech Stack

### What was done

1. Studied CI/CD and Jenkins theory one subtopic at a time.
2. Provisioned a Debian 12 VM on GCP, installed Java and Jenkins, and unlocked the web UI.
3. Built four jobs of increasing sophistication:
   - **Freestyle job** (UI-driven) with an archived artifact
   - **Declarative Pipeline** with stages, environment variables, post actions, and fingerprinted artifacts
   - **Credentials-bound Pipeline** showing automatic secret masking
   - **Multibranch Pipeline** that discovers `main` and `feature-payment` branches automatically
4. Deleted the VM and firewall rule.

### Tech Stack

| Layer | Technology | Role |
|---|---|---|
| Cloud | **GCP Compute Engine** (`e2-medium`, Debian 12) | Hosts the Jenkins controller |
| CI server | **Jenkins** (LTS) | Runs the automation |
| Runtime | **Java 21** (Eclipse Temurin) | Jenkins is a Java application |
| Source control | **Git** (local repo on the VM) | Provides branches and a `Jenkinsfile` |
| Network | **VPC firewall rule** (TCP 8080) | Exposes the Jenkins UI |
| Shell | **GCP Cloud Shell** | Provisioning and SSH |

### Lab architecture

```
 Browser ──HTTP :8080──► GCP VPC firewall (allow-jenkins-8080)
                                    │
                          ┌─────────▼──────────┐
                          │  jenkins-server VM │
                          │  Debian 12         │
                          │  ┌──────────────┐  │
                          │  │ Jenkins      │  │ ◄── JENKINS_HOME=/var/lib/jenkins
                          │  │ (Java 21)    │  │
                          │  └──────┬───────┘  │
                          │         │ clones    │
                          │  /tmp/sample-repo   │ ◄── branches: main, feature-payment
                          └────────────────────┘
```

---

## CI/CD Foundations

### 1. Continuous Integration (CI)

Developers merge small changes into a shared repository frequently, and an automated system builds and tests every change.

**Analogy: building a Lego castle with five friends.**
- *Without CI:* everyone builds a giant section alone for a month. At the end the tower does not fit the walls ("integration hell").
- *With CI:* every time you finish a small piece you snap it onto the main castle, and a robot inspector shakes the castle immediately. A broken piece is caught while it is still fresh in your mind.

**Example:** You change a button color from blue to green and push. Jenkins merges it, runs tests ("can the user still click Buy?"), and emails you if checkout broke.

### 2. Continuous Delivery vs. Continuous Deployment

| | **Continuous Delivery** | **Continuous Deployment** |
|---|---|---|
| Automated build and test | Yes | Yes |
| Ready to release at any moment | Yes | Yes |
| Human approval before production | **Yes** | **No** |
| Analogy | Chef plates the dish; a waiter carries it to the table | Sushi conveyor belt delivers straight to the customer |

### 3. GitOps

Git is the **single source of truth** for what your systems should look like. An automated agent continuously makes reality match the repository.

**Analogy: the magical notebook and the robot butler.** You write "Temperature: 72" in the notebook. The butler sets the heater to 72. If a friend changes the thermostat to 80, the butler notices the mismatch and changes it back.

**Example:** To scale from 2 servers to 5 you change `server_count: 2` to `5` in Git. A tool like Argo CD detects the commit and applies it. Manual changes get reverted automatically.

> **Key takeaway:** CI proves the code works. CD gets it to users. GitOps keeps the running system honest.

---

## Jenkins Core Theory

### 1. Architecture and core components

#### Controller-Agent (formerly Master-Node)

- **Controller:** the brain. Serves the UI, stores configuration, schedules jobs. Should **not** run builds in production.
- **Agents:** worker machines (VMs, physical servers, or temporary containers) that execute the builds and report back.

**Analogy: a construction site.** The Controller is the foreman in the site office with the blueprints. Agents are the workers who swing the hammers.

**Example:** A 2-hour, 32 GB game build runs on a high-CPU agent, so the controller stays fast for everyone else.

#### JENKINS_HOME

The one folder where Jenkins stores **everything**: configuration, plugins, job definitions, build history, and credentials.

| Path | Contents |
|---|---|
| `JENKINS_HOME/jobs/` | Job configs and build logs |
| `JENKINS_HOME/plugins/` | Installed plugins |
| `JENKINS_HOME/secrets/` | Encryption keys and the initial admin password |
| `JENKINS_HOME/config.xml` | Global configuration (including security settings) |

On Debian packages this is `/var/lib/jenkins`.

**Analogy: a locked filing cabinet.** Jenkins is the office manager. If the manager quits, hire a new one (reinstall), point them at the same cabinet, and business continues.

> **Backup rule:** back up `JENKINS_HOME`. Migrating Jenkins is mostly copying that folder.

#### Executors and the build queue

An **executor** is one slot that can run one build at a time. If every executor is busy, new builds wait in the **build queue**.

**Analogy: supermarket checkout.** Executors are the open registers; the queue is the line of shoppers. Five shoppers, two registers: two are served, three wait.

### 2. Job types

| Type | How it is defined | Best for | Weakness |
|---|---|---|---|
| **Freestyle** | Clicking through the UI | Quick, simple tasks | Cannot be version-controlled; no history of changes |
| **Pipeline** | A `Jenkinsfile` (Groovy) in Git | The modern standard | Requires learning the syntax |
| **Multibranch Pipeline** | A `Jenkinsfile` per branch, auto-discovered | Teams using feature branches and PRs | Needs a repository with a `Jenkinsfile` |

**Analogies:** Freestyle is telling the barista your order out loud every day. Pipeline is handing over a written order card that can be edited and kept.

#### Why Multibranch if the Jenkinsfile already filters branches?

Branch filters inside a Jenkinsfile control *whether stages run*. They do not give you:

1. **Separate history per branch.** A single pipeline job mixes `main` and feature builds into one list, so you cannot tell whether `main` is stable.
2. **Automatic pull request builds.** Multibranch detects PRs and tests them before merge.
3. **Zero manual setup.** New branches get their own pipeline automatically, and deleted branches are cleaned up.

**Analogy:** One shared whiteboard everyone erases vs. a private whiteboard handed to each developer when they open a branch.

### 3. Pipeline as Code (the Jenkinsfile)

#### Declarative vs. Scripted

| | **Declarative** | **Scripted** |
|---|---|---|
| Starts with | `pipeline { }` | `node { }` |
| Style | Structured template: say *what* you want | Full Groovy programming: say *how* |
| Error handling | Built in (`post { failure { } }`) | Manual `try/catch` |
| Readability | High | Lower |
| Typical use | About 95% of teams | Complex custom logic |

**Analogy:** Declarative is ticking boxes on a Subway order sheet. Scripted is writing a full instruction manual for the kitchen.

#### Pipeline anatomy

```groovy
pipeline {                 // outermost wrapper
  agent any                // WHERE to run
  stages {                 // container for all phases
    stage('Build App') {   // one phase
      steps {              // concrete commands
        sh 'npm install'
      }
    }
  }
}
```

**Analogy: a car factory.** `pipeline` is the building, `agent` the assembly room, `stages` the zones on the floor, `stage` the paint zone, `steps` the robot-arm actions.

#### Workspaces

A **workspace** is a temporary folder on the agent where Jenkins checks out code and runs the build (for example `/var/lib/jenkins/workspace/<job-name>`). Different jobs get different workspaces so files never mix.

**Analogy: a chef's cutting board.** Leftovers from the last dish can ruin the next one, which is why "clean workspace" is a common pipeline step.

### 4. Build triggers

| Trigger | How it works | Efficiency | Analogy |
|---|---|---|---|
| **SCM polling** | Jenkins asks the repo on a schedule ("anything new?") | Wasteful (288 checks/day at every 5 min) | A child asking "are we there yet?" |
| **Webhook** | The repo pushes an event to Jenkins on every commit | Near-zero idle load, instant | The doorbell when the pizza arrives |
| **Cron (timer)** | Runs at set times regardless of code changes | Predictable | A street sweeper on a fixed schedule |

```text
H/5 * * * *     # poll or run roughly every 5 minutes (H spreads load)
@midnight       # nightly
```

#### Webhooks in detail

A webhook is an automated HTTP message one app sends to another when an event happens.

1. **Setup:** In GitHub repository settings, add a webhook pointing to `http://<jenkins-host>/github-webhook/`.
2. **Event:** A developer pushes code.
3. **Payload:** GitHub creates a small JSON document (event type, author, branch, commit).
4. **Delivery:** GitHub POSTs it to the Jenkins URL.
5. **Action:** Jenkins reads it and starts the pipeline for that branch in about a second.

**Analogy:** Instead of driving to the ATM every 15 minutes (polling), you enable an SMS alert for deposits (webhook).

> **Practical note:** A webhook needs Jenkins reachable from GitHub. For a private Jenkins, use a reverse proxy, a tunnel, or fall back to polling.

### 5. Artifacts and traceability

- **Archiving artifacts:** Saves a build's output (`.jar`, `.zip`, image reference) on the controller so it survives workspace cleanup and can be downloaded from the build page.
  *Analogy: moving the finished cake into the display case before the kitchen is cleaned.*
- **Fingerprinting:** Records an MD5 checksum of an artifact so Jenkins can trace exactly which build produced it and which jobs consumed it.
  *Analogy: the VIN stamped on a car. If something fails later, look up the VIN to find the factory and day.*

### 6. Security and credentials

- **Credentials Binding:** Store secrets (tokens, SSH keys, passwords) once in the Jenkins credentials store and reference them by ID. Jenkins injects them at run time and masks them in logs (`****`).
  *Analogy: a hotel safe that hands keys to the valet and records who took them.*
- **RBAC (Role-Based Access Control):** Plugins such as **Matrix Authorization Strategy** limit what each user can do.
  *Analogy: hospital ID badges. The nurse's badge opens patient rooms, not the pharmacy.*

| Role | Typical permissions |
|---|---|
| Developer | Read, Build |
| QA | Read, Build on test jobs |
| DevOps Admin | Configure, delete jobs, manage plugins |

### 7. Extensibility

- **Plugins:** Jenkins core is a scheduling engine. Plugins teach it to talk to Git, Docker, Kubernetes, Slack, SonarQube, and more.
  *Analogy: apps on a smartphone.* For example, the Slack plugin adds `slackSend(color: 'danger', message: 'Build Failed')`.
- **Shared Libraries:** Reusable Groovy code kept in a central Git repository and imported by many Jenkinsfiles.
  *Analogy: franchise recipes. Corporate updates one master book and every restaurant follows.*

```groovy
// vars/deployToGCP.groovy  (in the shared library repo)
def call(String service) {
  sh "gcloud run deploy ${service} --quiet"
}

// Jenkinsfile in any project
@Library('company-shared-lib') _
pipeline {
  agent any
  stages {
    stage('Deploy') { steps { deployToGCP('my-service') } }
  }
}
```

### 8. Ecosystem concepts

| Concept | Idea | Analogy |
|---|---|---|
| **Docker builds** | Package app and dependencies into a standard container so builds behave the same everywhere | A standard shipping container |
| **SonarQube (static analysis)** | Scans source code for bugs, vulnerabilities, and hardcoded secrets before it is built | A proofreader before the book goes to print |
| **Observability** (Prometheus and Grafana) | Track build times, failure rates, and Jenkins health | A car dashboard |
| **Argo CD** | GitOps engine that syncs a Kubernetes cluster to Git | The robot butler |

---

## Jenkins vs. GitHub Actions and Other Tools

**Analogy:** Jenkins is **building your own custom factory**: total control, endless machines (plugins), but you pay the electricity and fix the roof. GitHub Actions is **renting a managed workshop attached to your design room**: zero maintenance, but you use their tools.

| | **Jenkins** | **GitHub Actions** |
|---|---|---|
| Hosting | You run it (VM, Kubernetes) | Managed by GitHub |
| Cost | Software free; you pay for servers and engineer time | Free tier, then pay per minute |
| Customization | Very high (about 1,800 plugins) | High, mostly via marketplace actions |
| Maintenance | Patching, upgrades, plugin compatibility are yours | None |
| Learning curve | Steeper | Gentler (YAML) |
| Data stays in your network | Yes | Only with self-hosted runners |
| Vendor lock-in | Low | Tied to GitHub |

**Choose Jenkins** for large enterprises, legacy integrations, strict on-premises or compliance requirements, and when you have a team to run it.
**Choose GitHub Actions** for startups and cloud-native projects already on GitHub that want developers focused on code, not infrastructure.

### Other CI/CD tools by category

| Category | Tools |
|---|---|
| Managed and cloud-native | GitHub Actions, GitLab CI/CD, CircleCI, Bitbucket Pipelines, Travis CI |
| Self-hosted and enterprise | Jenkins, TeamCity, Bamboo, GoCD |
| Cloud-provider native | AWS CodePipeline, Google Cloud Build, Azure DevOps |
| Container-first and GitOps (delivery) | Argo CD, Harness, Flux |

---

## Practical Lab on GCP

> **Safety rules for a company account:**
> - Run all cleanup **only at the very end** (see [Teardown](#teardown-and-cost-optimization)).
> - Use a clearly named, tagged lab VM and a dedicated firewall rule so nothing can be confused with production.
> - Replace `<YOUR_PROJECT_ID>` with your own project, and `<EXTERNAL_IP>` with the VM's public IP.

### Step 1: Provision the VM and firewall rule

An `e2-medium` is about the minimum comfortable size for Jenkins; smaller VMs often run out of memory.

```bash
gcloud compute instances create jenkins-server \
  --machine-type=e2-medium \
  --zone=us-central1-a \
  --tags=jenkins-server

gcloud compute firewall-rules create allow-jenkins-8080 \
  --direction=INGRESS \
  --priority=1000 \
  --network=default \
  --action=ALLOW \
  --rules=tcp:8080 \
  --source-ranges=0.0.0.0/0 \
  --target-tags=jenkins-server
```

> **Tighten this:** `0.0.0.0/0` exposes the login page to the whole internet over plain HTTP. For anything longer than a short lab, replace it with your own public IP (`<YOUR_IP>/32`).

SSH in (wait 30 to 45 seconds after creation, or you will see "Connection refused"):

```bash
gcloud compute ssh jenkins-server --zone=us-central1-a
```

### Step 2: Install Java 21

Current Jenkins releases require **Java 21 or newer**. Debian 12's default repositories stop at Java 17, so install **Eclipse Temurin 21** from Adoptium.

```bash
sudo mkdir -p /etc/apt/keyrings

wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public \
  | sudo tee /etc/apt/keyrings/adoptium.asc > /dev/null

echo "deb [signed-by=/etc/apt/keyrings/adoptium.asc] https://packages.adoptium.net/artifactory/deb $(awk -F= '/^VERSION_CODENAME/{print $2}' /etc/os-release) main" \
  | sudo tee /etc/apt/sources.list.d/adoptium.list

sudo apt-get update
sudo apt-get install -y temurin-21-jdk fontconfig

java -version      # should report 21.x
```

| Command | What it does |
|---|---|
| `mkdir -p /etc/apt/keyrings` | Creates the folder that stores repository signing keys |
| `wget ... \| tee` | Downloads the publisher's GPG key so `apt` can verify packages are genuine |
| `echo "deb [signed-by=...] ..." \| tee` | Registers the Adoptium repository and ties it to that key |
| `apt-get update` | Refreshes the package index so the new repository is visible |
| `apt-get install temurin-21-jdk` | Installs Java 21 |

### Step 3: Install Jenkins

Jenkins periodically rotates its repository signing key. If `apt-get update` shows `NO_PUBKEY`, you are using an outdated key file. Fetch the current one from the [Jenkins Debian installation page](https://www.jenkins.io/doc/book/installing/linux/#debianubuntu) (at the time of this lab it was `jenkins.io-2026.key`).

```bash
sudo wget -O /usr/share/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key

echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" \
  | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null

sudo apt-get update
sudo apt-get install -y jenkins

sudo systemctl enable jenkins     # start on every boot
sudo systemctl start jenkins      # start now
sudo systemctl status jenkins --no-pager
```

> **Note:** The whole `deb [signed-by=...] URL suite` entry must be **inside one pair of quotes**. A closing quote before the URL produces a broken repository line.

You want `active (running)`.

### Step 4: Unlock Jenkins and run the setup wizard

```bash
sudo cat /var/lib/jenkins/secrets/initialAdminPassword   # unlock password
curl -s ifconfig.me                                      # VM public IP
```

1. Open `http://<EXTERNAL_IP>:8080`.
2. Paste the 32-character password and click **Continue**.
3. Choose **Install suggested plugins** (Git, Pipeline, Credentials, SSH Agent, Workspace Cleanup, and more).
4. Create the first admin user (username, password, name, email).
5. Keep the suggested Jenkins URL, click **Save and Finish**, then **Start using Jenkins**.

### Lab 1: Freestyle job

**Goal:** See how Jenkins creates a workspace, runs shell commands, and logs output.

1. **New Item**, name it `01-first-freestyle-job`, choose **Freestyle project**, click **OK**.
2. Under **Build Steps**, choose **Add build step, Execute shell**, and paste:

```bash
echo "=== Running First Jenkins Build ==="
date
hostname
pwd
echo "Hello from Jenkins Build #$BUILD_NUMBER" > build_artifact.txt
ls -la
```

3. **Save**, click **Build Now**, open build **#1**, then **Console Output**.

| Line | Shows you |
|---|---|
| `date` | When the build ran |
| `hostname` | Which machine executed it (the controller, in this lab) |
| `pwd` | The workspace path Jenkins created |
| `echo ... > build_artifact.txt` | A file created inside the workspace using the built-in `$BUILD_NUMBER` |
| `ls -la` | Proof the file exists |

#### Archive the artifact

1. Open **Configure**, scroll to **Post-build Actions**, choose **Archive the artifacts**.
2. Files to archive: `build_artifact.txt`. **Save**.
3. **Build Now**. On the new build page, `build_artifact.txt` appears under **Build Artifacts** for download.

### Lab 2: Declarative Pipeline

**Goal:** Pipeline as Code with stages, environment variables, post actions, and fingerprinting.

Create a **Pipeline** item named `02-declarative-pipeline`, set Definition to **Pipeline script**, and paste:

```groovy
pipeline {
  agent any

  environment {
    APP_NAME  = 'Sample Portal'
    BUILD_ENV = 'Testing'
  }

  stages {
    stage('Environment Check') {
      steps {
        echo "Building application: ${env.APP_NAME}"
        echo "Deploying to environment: ${env.BUILD_ENV}"
        echo "Current Build Number: ${env.BUILD_NUMBER}"
      }
    }

    stage('Build Phase') {
      steps {
        echo 'Compiling code into a deployment package...'
        sh 'echo "Compiled binary for ${APP_NAME}" > application.bin'
      }
    }

    stage('Test Phase') {
      steps {
        echo 'Running automated unit tests...'
        sh 'test -f application.bin'
        echo 'Tests Passed!'
      }
    }

    stage('Archive Artifacts') {
      steps {
        archiveArtifacts artifacts: 'application.bin', fingerprint: true
      }
    }
  }

  post {
    always  { echo 'Pipeline execution finished.' }
    success { echo 'Pipeline passed all stages!' }
    failure { echo 'Pipeline execution failed!' }
  }
}
```

**Build Now**, then watch the **Stage View** (one green box per stage). The `test -f` step fails the stage if the file is missing, which is how a real test gate behaves.

| Block | Purpose |
|---|---|
| `environment` | Variables available to every stage |
| `stages` / `stage` | The visible phases in Stage View |
| `post { always / success / failure }` | Actions that run depending on the final result |
| `fingerprint: true` | Tracks this artifact across jobs |

### Lab 3: Credentials binding

**Goal:** Inject a secret without exposing it in code or logs.

1. **Manage Jenkins, Credentials, (global), Add Credentials**.
2. Kind: **Secret text**. Scope: **Global**. Secret: `<a-dummy-lab-value>`. ID: `my-api-token`. Description: any. **Create**.
3. Create a Pipeline item `03-credentials-pipeline`:

```groovy
pipeline {
  agent any

  environment {
    MY_SECRET_TOKEN = credentials('my-api-token')
  }

  stages {
    stage('Authenticate and Deploy') {
      steps {
        echo 'Accessing remote API securely...'
        sh '''
          echo "Attempting login with token: $MY_SECRET_TOKEN"
        '''
      }
    }
  }
}
```

4. **Build Now**, open **Console Output**. The log shows `Attempting login with token: ****`.

> **Important:** Use single-quoted `sh '''...'''` so the **shell** reads `$MY_SECRET_TOKEN`. With double quotes, Groovy would interpolate the secret into the command string, which Jenkins warns against. Masking only hides the exact value; transformed copies (for example base64-encoded) are not masked. Never deliberately print secrets.

### Lab 4: Multibranch Pipeline

**Goal:** Let Jenkins discover branches and create a pipeline for each automatically.

Run these **on the Jenkins VM** (not in Cloud Shell):

```bash
sudo apt-get update && sudo apt-get install -y git

mkdir -p /tmp/sample-repo && cd /tmp/sample-repo
git init -b main
git config user.email "devops@example.com"
git config user.name  "DevOps Engineer"

cat << 'EOF' > Jenkinsfile
pipeline {
  agent any
  stages {
    stage('Main Branch Pipeline') {
      steps { echo "Executing pipeline on MAIN branch" }
    }
  }
}
EOF
git add . && git commit -m "Initial commit on main"

git checkout -b feature-payment
cat << 'EOF' > Jenkinsfile
pipeline {
  agent any
  stages {
    stage('Feature Branch Pipeline') {
      steps { echo "Executing pipeline on FEATURE-PAYMENT branch" }
    }
  }
}
EOF
git add . && git commit -m "Update Jenkinsfile for feature-payment branch"

# Jenkins runs as the 'jenkins' user and must be able to read the repo
sudo chown -R jenkins:jenkins /tmp/sample-repo
sudo chmod -R 755 /tmp/sample-repo
```

Then in Jenkins:

1. **New Item**, name `04-multibranch-pipeline`, choose **Multibranch Pipeline**.
2. **Branch Sources, Add source, Git**. Project Repository: `/tmp/sample-repo` (or `file:///tmp/sample-repo` if the plain path errors).
3. **Save**, then click **Scan Multibranch Pipeline Now**. Check **Scan Multibranch Pipeline Log** if nothing appears.
4. You should see two sub-pipelines, `main` and `feature-payment`, each with its own build history.
5. If an initial build shows a red X because it ran before Git was installed, trigger it again with the play icon.

> **Real-world equivalent:** replace the local path with a GitHub or GitLab repository, add a credential for private repos, and add a webhook so branch and PR events trigger scans and builds instantly.

---

## Real-World Troubleshooting / Errors Faced

### Error 1: `ssh: connect to host ... port 22: Connection refused`

**Cause:** The VM was created seconds earlier. It was powered on, but SSH had not started yet.
**Fix:** Wait 30 to 45 seconds and retry `gcloud compute ssh`.

### Error 2: `NO_PUBKEY` and "repository is not signed"

**Symptom:** `apt-get update` warns the Jenkins repository is not signed, then `Package 'jenkins' has no installation candidate`.
**Cause:** The Jenkins repository signing key had rotated, and the old key file no longer matched.
**Fix:** Download the current key from the official Jenkins installation page, rewrite the `sources.list.d` entry, then `apt-get update` again.

### Error 3: `Failed to enable unit: Unit file jenkins.service does not exist`

**Cause:** A follow-on effect of Error 2. The package never installed, so no service file existed.
**Fix:** Fix the repository key and install Jenkins first.

### Error 4: `jenkins.service` fails to start (`status=1/FAILURE`)

**Symptom:** `systemctl status` shows `exit-code` and an auto-restart loop, but the real message is cut off with `>`.
**Diagnosis:** Read the full log instead of the summary:

```bash
sudo journalctl -u jenkins.service -n 30 --no-pager
```

**Cause:** Jenkins started without a suitable Java runtime. Installing Java 17 was still not enough.

### Error 5: "Running with Java 17 ... older than the minimum required version (Java 21)"

**Cause:** Current Jenkins releases support only Java 21 and 25.
**Fix:** Install Java 21.

### Error 6: `E: Unable to locate package openjdk-21-jre`

**Cause:** Debian 12 (bookworm) packages only up to OpenJDK 17.
**Fix:** Add the **Adoptium (Temurin)** repository and install `temurin-21-jdk` (see Step 2), then `sudo systemctl restart jenkins`.

### Error 7: Pager truncates output (`lines 1-15/15 (END)`)

**Cause:** `systemctl status` opens a pager and cuts long lines.
**Fix:** Press `q` to exit and use `--no-pager`, or read logs with `journalctl --no-pager`.

### Error 8: Commands run in the wrong shell

**Symptom:** `sudo cat /var/lib/jenkins/secrets/initialAdminPassword` fails with "No such file" or `git: command not found`, or `/tmp/sample-repo` is missing from Jenkins.
**Cause:** The prompt was `...@cloudshell`, not `...@jenkins-server`. Jenkins files and the Git repo exist only on the VM.
**Fix:** Always check the prompt. SSH into the VM first: `gcloud compute ssh jenkins-server --zone us-central1-a`.

### Error 9: Logged out and forgot the admin password

**Fix options:**
- If the setup wizard was never completed, the `initialAdminPassword` file still holds the password.
- Otherwise, temporarily disable security, reset the password, and re-enable it:

```bash
sudo sed -i 's#<useSecurity>true</useSecurity>#<useSecurity>false</useSecurity>#' /var/lib/jenkins/config.xml
sudo systemctl restart jenkins
# In the UI: Manage Jenkins, Users, admin, Configure, set a new password

sudo sed -i 's#<useSecurity>false</useSecurity>#<useSecurity>true</useSecurity>#' /var/lib/jenkins/config.xml
sudo systemctl restart jenkins
```

> **Warning:** While security is disabled, **anyone who can reach port 8080 has full admin access**. Do this on a lab VM only, and finish it quickly. Better yet, restrict the firewall to your own IP first.

### Error 10: Multibranch scan fails: `Cannot run program "git"`

**Cause:** Git was not installed on the Jenkins host.
**Fix:** `sudo apt-get install -y git`, then re-scan.

### Error 11: Scan succeeds ("Done") but no branches appear

**Cause:** Jenkins runs as the `jenkins` system user, which could not read `/tmp/sample-repo` created by another user.
**Fix:** `sudo chown -R jenkins:jenkins /tmp/sample-repo`, then **Scan Multibranch Pipeline Now**. Read the **Scan Multibranch Pipeline Log** for the real reason.

### Error 12: Branches show a red X on build #1

**Cause:** Jenkins auto-built each branch before Git was installed.
**Fix:** Click the play icon on each branch to rebuild.

### Troubleshooting cheat sheet

| Symptom | Likely cause | First thing to check |
|---|---|---|
| Cannot open `http://IP:8080` | Firewall or service down | Firewall rule/target tag, `systemctl status jenkins` |
| `jenkins.service` fails immediately | Wrong or missing Java | `java -version`, `journalctl -u jenkins` |
| `NO_PUBKEY` during `apt update` | Rotated repo signing key | Re-download the key from the official page |
| Job cannot find a tool (`git`, `docker`) | Tool missing on the agent | Install it where the build runs |
| Permission denied reading files | Jenkins user lacks access | `ls -l`, `chown` to `jenkins` |
| Multibranch finds no branches | No `Jenkinsfile`, bad path, or permissions | Scan log |
| Secret appears in log | Interpolated in Groovy or transformed | Use single quotes and `credentials()` |

---

## Beyond the Lab: Production Roadmap

These topics were part of the study plan but were not built in the lab. Treat them as your next steps.

| Topic | Why it matters | What to do |
|---|---|---|
| **Agents instead of building on the controller** | Builds on the controller can freeze the UI | Attach GCE VMs or Kubernetes pod agents; set controller executors to 0 |
| **Webhooks** | Instant triggers instead of polling | Add a GitHub webhook to `/github-webhook/` and enable the trigger on the job |
| **Docker in pipelines** | Reproducible build environments | Use `agent { docker { image 'node:20' } }` and give the Jenkins user Docker access |
| **SonarQube quality gate** | Fail builds on bugs, vulnerabilities, and secrets | Install the SonarQube plugin, add a server and token credential, add `withSonarQubeEnv` and `waitForQualityGate` |
| **Argo CD (CD stage)** | GitOps delivery to Kubernetes | Jenkins builds the image and updates the manifest in Git; Argo CD syncs the cluster |
| **Shared Libraries** | Standardize pipelines across many repos | Move repeated steps into a central library |
| **RBAC** | Least-privilege access | Install Matrix Authorization Strategy or Role-based Authorization Strategy |
| **External secrets** | Avoid long-lived secrets in Jenkins | Integrate HashiCorp Vault, Google Secret Manager, or AWS Secrets Manager |
| **Backup and disaster recovery** | Jenkins data is a single point of failure | Back up `JENKINS_HOME` (snapshots or ThinBackup); rebuild with Terraform and Jenkins Configuration as Code |
| **Observability** | Spot slow or failing pipelines early | Prometheus plugin and a Grafana dashboard |
| **HTTPS and reverse proxy** | Port 8080 over HTTP is unencrypted | Put Nginx or a load balancer with TLS in front (see the companion SSL/TLS README) |

Example Docker agent snippet:

```groovy
pipeline {
  agent { docker { image 'node:20-alpine' } }
  stages {
    stage('Build') { steps { sh 'npm ci && npm run build' } }
    stage('Test')  { steps { sh 'npm test' } }
  }
}
```

---

## DevOps Interview Guide

### Part A: Standard Questions

**Q1. What is Jenkins and why is it used?**
> An open-source automation server written in Java that orchestrates building, testing, and deploying software. It is used to automate CI/CD, and its plugin ecosystem lets it integrate with almost any tool.

**Q2. Explain the Controller-Agent architecture.**
> The controller manages configuration, scheduling, and the UI. Agents (VMs, containers, or physical machines) execute builds and report results. Production setups keep the controller free of builds so it stays responsive and secure.

**Q3. What is a Jenkinsfile and why use Pipeline as Code?**
> A text file defining the pipeline, stored in the application repository. It is version-controlled, reviewable, reproducible, and restorable if Jenkins is lost.

**Q4. Declarative vs. Scripted pipelines?**
> Declarative (`pipeline { }`) is structured, readable, and has built-in features like `post` and `when`. Scripted (`node { }`) is plain Groovy with full flexibility but more complexity and manual error handling.

**Q5. Freestyle vs. Pipeline vs. Multibranch?**
> Freestyle is UI-configured and not version-controlled. Pipeline is code-driven. Multibranch discovers branches and PRs and creates a pipeline for each, with clean per-branch history.

**Q6. Webhooks vs. SCM polling?**
> Webhooks push an event to Jenkins on a commit (instant, efficient). Polling makes Jenkins ask on a schedule (wasteful, delayed, heavy at scale).

**Q7. What is `JENKINS_HOME`?**
> The directory holding all configuration, jobs, build history, plugins, and credentials. Backing it up is the core of Jenkins backup and migration.

**Q8. What are executors and the build queue?**
> An executor is a slot that runs one build. When all executors are busy, builds wait in the queue.

**Q9. How does Jenkins manage secrets?**
> Through the Credentials store with scoped IDs, injected with `credentials()` or `withCredentials`, and masked in logs. Use external vaults for stronger control.

**Q10. What is fingerprinting?**
> Recording a checksum of artifacts so Jenkins can show which build produced a file and where it was used, for traceability.

### Part B: Tricky and Edge-Case Questions

**Q: "Jenkins will not start after installation. How do you diagnose it?"**
> Check `systemctl status jenkins`, then read the full logs with `journalctl -u jenkins -n 50 --no-pager`. The most common causes are an unsupported or missing Java version, insufficient memory, a port conflict on 8080, or permissions on `JENKINS_HOME`. Verify with `java -version` against the Java versions the Jenkins release supports.

**Q: "Why should builds not run on the controller?"**
> Builds consume CPU and memory and can freeze the UI for everyone. They also execute potentially untrusted code on the machine that holds all credentials and configuration. Agents isolate that risk and scale horizontally.

**Q: "A secret appeared in a build log despite using credentials. Why?"**
> Masking replaces only the exact secret string. Groovy string interpolation in double quotes, encoding or splitting the value, or tools that echo it in another form can bypass masking. Use single-quoted shell blocks, avoid printing secrets, and rotate any secret that leaked.

**Q: "Multibranch scan says 'Done' but shows no branches. Why?"**
> Common causes: no `Jenkinsfile` in the branches, the Jenkins user cannot read the repository, a wrong URL or credential, missing Git on the host, or branch filters excluding everything. The **Scan Log** tells you which.

**Q: "How do you stop two jobs from corrupting each other's files?"**
> Each job gets its own workspace by default. For concurrent builds of the same job, Jenkins appends suffixes to the workspace name. Clean the workspace at start or end to avoid stale files, and use the `lock` or `disableConcurrentBuilds` options for shared external resources.

**Q: "How would you recover if the Jenkins server was destroyed?"**
> Restore the `JENKINS_HOME` backup onto a new instance (same or newer Jenkins version, compatible Java and plugins). If the setup is codified (Terraform for the VM, Jenkins Configuration as Code for settings, Jenkinsfiles in Git), you can rebuild with almost no manual work, which is the real value of Pipeline as Code.

**Q: "Jenkins vs. GitHub Actions: which would you choose?"**
> It depends. Jenkins suits enterprises needing on-premises control, legacy integrations, and deep customization, at the cost of maintenance. GitHub Actions suits teams on GitHub who want zero infrastructure management; cost can grow with heavy usage.

**Q: "What is the difference between CI, Continuous Delivery, and Continuous Deployment?"**
> CI merges and tests code frequently. Continuous Delivery keeps every change releasable with a manual approval gate. Continuous Deployment removes the gate and releases automatically after passing tests.

**Q: "How do you scale Jenkins for hundreds of pipelines?"**
> Use dynamic agents (Kubernetes pods or cloud VMs), shared libraries to standardize logic, Multibranch or Organization Folders for auto-discovery, webhooks instead of polling, RBAC for team isolation, and monitoring to spot bottlenecks.

---

## Teardown and Cost Optimization

> **Run this only when every exercise is finished.** In this lab the VM and firewall rule were deleted early once by mistake, and the environment had to be rebuilt. Cleanup always goes last.

Run these in **Cloud Shell** (not on the VM):

```bash
# 1. Delete the Jenkins VM (this also removes its boot disk by default)
gcloud compute instances delete jenkins-server --zone us-central1-a --quiet

# 2. Delete the firewall rule
gcloud compute firewall-rules delete allow-jenkins-8080 --quiet
```

Verify nothing remains:

```bash
gcloud compute instances list
gcloud compute firewall-rules list --filter="name=allow-jenkins-8080"
gcloud compute disks list
```

| Cost tip | Why |
|---|---|
| Delete the VM, not just stop it, when the lab is over | A stopped VM still bills for its disk |
| Remove the firewall rule | An open port 8080 is both a risk and clutter |
| Use `e2-medium` only for as long as needed | Jenkins needs memory, but the VM is not free |
| Set a billing budget alert | Catches forgotten resources early |
| Check `gcloud compute disks list` | Orphaned disks keep billing |

---

## Security Notes

> **A short-lived lab is not a production setup.** Review these before reusing anything here.

- **Do not leave Jenkins on plain HTTP on the public internet.** Restrict the firewall to your IP, or place Jenkins behind a TLS-terminating reverse proxy or load balancer.
- **Disabling Jenkins security** (Error 9) gives anyone with network access full control, including the ability to run code on the server and read stored credentials. Never do this on a reachable production system.
- **Never commit secrets** to a `Jenkinsfile` or repository. Use the credentials store or an external secrets manager.
- The secret used in the credentials lab was a dummy value. Use a unique, rotated value for real tokens, and rotate immediately if one is ever printed or pasted in a chat or log.
- Keep Jenkins and its plugins updated. Plugin vulnerabilities are the most common way Jenkins servers get compromised.
- Apply least privilege with RBAC, and run builds on agents rather than the controller.

---

### Suggested Repository Layout

```
jenkins-learning/
├── README.md
├── pipelines/
│   ├── 01-freestyle-notes.md
│   ├── 02-declarative-pipeline.Jenkinsfile
│   ├── 03-credentials-pipeline.Jenkinsfile
│   └── 04-multibranch-sample/
│       └── Jenkinsfile
├── scripts/
│   ├── install-java21.sh
│   └── install-jenkins.sh
└── .gitignore
```

### Further Reading

- [Jenkins User Documentation](https://www.jenkins.io/doc/)
- [Installing Jenkins on Linux](https://www.jenkins.io/doc/book/installing/linux/)
- [Pipeline Syntax Reference](https://www.jenkins.io/doc/book/pipeline/syntax/)
- [Jenkins Shared Libraries](https://www.jenkins.io/doc/book/pipeline/shared-libraries/)
- [Jenkins Configuration as Code](https://www.jenkins.io/projects/jcasc/)

---

*Built while learning. Corrections and contributions welcome.*
