A new release can be created by one of the main DOMjudge developers.
The following steps should be taken (most can be done on your local
computer, but absolute paths refer to those on the account
`domjudge@domjudge.org`):

 1. Test everything. (duh...)
 1. Commit the correct version number in the `ChangeLog` and `README` files.
 1. Discuss if the current second to last minor version will now be
    End-of-Life and update `SECURITY.md` as needed.
 1. When releasing a new major or minor version, change the constants
    `CCS_SPEC_API_{VERSION,URL}` in `webapp/src/Controller/API/GeneralInfoController.php`
	to point to the correct CCS API version.
 1. Declare the new tag (to be used in further commands):
    ```sh
	export TAG=x.y.z
	export BRANCH=${TAG%.?}
	```
 1. Create a release version `$TAG`:
    ```sh
    git tag -s -m "Tag release version $TAG." $TAG
    ```
    See `git tag --help` for more details on how to tag with(out) a
    GPG signature.
 1. If releasing from the main branch, create a new version branch:
    ```sh
    git checkout -b $BRANCH
    git push --set-upstream origin $BRANCH
    git checkout main
    ```
 1. Push everything to the central Git repository (including the
    release tags, since these are not pushed by default):
	```sh
    git push origin $BRANCH refs/tags/$TAG
    ```
    This triggers a release tarball to be built and published on
    `domjudge.org`: the cronjob `cron_tag_release.sh` picks up new
    tags and calls `make_release.sh` to publish the tarball in
    `/srv/http/domjudge/releases` together with a checksum file.
 1. Update `ChangeLog` and `README` to `{version+1}DEV` and commit.
 1. Update the DOMjudge homepage: commit changes in the `domjudge-scripts`
    repository under `website/` and run `make install` from
	`~/domjudge-scripts/website` on `domjudge.org`.
 1. If this is a new major or minor version, update the release documentation
    under `/srv/http/domjudge/docs/manual` by adding a new version to
    the file `versions.json` and remove any unsupported versions.
    Update the redirect destination in `index.html` and `team.html`.
    The documentation is regenerated once every hour.
 1. If this is a new major or minor version, add the new version to
    `.github/dependabot.yml`.
 1. Bump the Docker images by starting a new pipeline
    [here](https://gitlab.com/DOMjudge/domjudge-packaging/-/pipelines/new) and
    setting `DOMJUDGE_VERSION` to the version to release. Set `DOMJUDGE_LATEST`
    to true if this is the latest version or `false` if it is not. After clicking
    `Run pipeline`, make sure to click the *play* button next to `release-DOMjudge`
    to actually build and push the Docker images. You can view the progress by
    clicking on the job.
 1. Update https://gitlab.com/DOMjudge/domjudge-packaging/-/pipeline\_schedules to the latest version.
 1. Build Debian packages (or make someone do this).
 1. Put the Debian packages in `/srv/http/domjudge/debian/mini-dinstall/incoming`
    and run as `domjudge@domjudge.org`:
	```sh
	mini-dinstall -b
    ```
 1. Send an email to `domjudge-announce@domjudge.org`, announcing the
    new version and state which versions are supported.
