#!/usr/bin/env bash

set -Eeuo pipefail
umask 077

decode() {
  printf '%s' "$1" | base64 --decode
}

runner_url="$(decode "${RUNNER_URL_B64:?RUNNER_URL_B64 is required}")"
runner_token="$(decode "${RUNNER_TOKEN_B64:?RUNNER_TOKEN_B64 is required}")"
runner_labels="$(decode "${RUNNER_LABELS_B64:?RUNNER_LABELS_B64 is required}")"
runner_name="$(decode "${RUNNER_NAME_B64:?RUNNER_NAME_B64 is required}")"

readonly runner_user='githubrunner'
readonly runner_dir='/opt/actions-runner'
readonly runner_version='2.336.0'

case "$(uname -m)" in
  x86_64)
    runner_arch='x64'
    runner_sha256='04cf0be1aff4c3ec3554466c39124ca250e3effd8873bb7e8d68535aa9505d5d'
    ;;
  aarch64)
    runner_arch='arm64'
    runner_sha256='58b758e420b87093fbd4bfddd368074960053e2f1388f01848c82624b90f27d1'
    ;;
  *)
    echo "Unsupported architecture: $(uname -m)" >&2
    exit 1
    ;;
esac

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install --yes ca-certificates curl git jq libicu-dev sudo

packages_deb='/tmp/packages-microsoft-prod.deb'
curl --fail --location --retry 5 \
  --output "$packages_deb" \
  'https://packages.microsoft.com/config/ubuntu/24.04/packages-microsoft-prod.deb'
dpkg --install "$packages_deb"
rm -f "$packages_deb"

apt-get update
apt-get install --yes azure-cli powershell

if ! id "$runner_user" >/dev/null 2>&1; then
  useradd --create-home --shell /bin/bash "$runner_user"
fi

sudo --user "$runner_user" --set-home az bicep install
install --mode 0755 "/home/${runner_user}/.azure/bin/bicep" /usr/local/bin/bicep

if [[ -x "${runner_dir}/svc.sh" ]]; then
  "${runner_dir}/svc.sh" stop || true
  "${runner_dir}/svc.sh" uninstall || true
fi

rm -rf "$runner_dir"
install --directory --owner "$runner_user" --group "$runner_user" "$runner_dir"

runner_archive="/tmp/actions-runner-${runner_version}.tar.gz"
runner_download_url="https://github.com/actions/runner/releases/download/v${runner_version}/actions-runner-linux-${runner_arch}-${runner_version}.tar.gz"
curl --fail --location --retry 5 --output "$runner_archive" "$runner_download_url"
printf '%s  %s\n' "$runner_sha256" "$runner_archive" | sha256sum --check
tar --extract --gzip --file "$runner_archive" --directory "$runner_dir"
rm -f "$runner_archive"

"${runner_dir}/bin/installdependencies.sh"
chown --recursive "${runner_user}:${runner_user}" "$runner_dir"

sudo --user "$runner_user" --set-home "${runner_dir}/config.sh" \
  --unattended \
  --replace \
  --url "$runner_url" \
  --token "$runner_token" \
  --name "$runner_name" \
  --labels "$runner_labels" \
  --work '_work'

"${runner_dir}/svc.sh" install "$runner_user"
"${runner_dir}/svc.sh" start

unset runner_token RUNNER_TOKEN_B64
