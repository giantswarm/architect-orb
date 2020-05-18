# push-to-app-collection

This job generate an App CR and add it to the an app collection chart repository.

* The App name, App namespace and catalog are passed by parameters (respectively `app_name`, `app_namespace` and `app_catalog`).
* The App CR annotation `chart-operator.giantswarm.io/force-helm-upgrade` can be configured with `disable_force_upgrade` parameter.
* The App version is automatically detected by `architect project version`.
* The app collection repository where the App CR is added to is passed by parameter (`app_collection_repo`).

**NOTE**: The job requires `CATALOGBOT_SSH_KEY_PRIVATE_BASE64` environment
variable to be set in the build. This must be base64 encoded private SSH key of
[CatalogBot Github user][catalogbot-user]. It is defined in [architect
context][architect-context] so it's enough to include `context: "architect"`
line in your workflow definitions.

**NOTE**: app collection repositories configured in the job parameters must be
added to the [Catalog Editors][catalog-editors-team] GitHub team with write permission. See the
paragraph below for explanation.

All interactions with the app collection GitHub repository are done with
[CatalogBot GitHub user][catalogbot-user] This job assumes that the app
collection is defined in a GitHub repository inside `"aws-app-collection"` the
job will try to use [giantswarm/aws-app-collection][aws-app-collection].
giantswarm organization. E.g. when `app_collection_repo` parameter is set to
user] credentials.

[architect-context]: https://circleci.com/gh/organizations/giantswarm/settings#contexts/ff685959-6b0d-48a9-a79d-4f1089caa3d6
[aws-app-collection]: https://github.com/giantswarm/aws-app-collection
[catalog-editors-team]: https://github.com/orgs/giantswarm/teams/bot-catalog-editors/repositories
[catalogbot-user]: https://github.com/catalogbot

Example usage

```yaml
version: 2.1
orbs:
  architect: giantswarm/architect@VERSION

workflows:
  my-workflow:
    jobs:
      - architect/push-to-app-collection:
          context: "architect"
          name: "push-REPOSITORY-to-COLLECTION-app-collection"
          app_name: "REPOSITORY"
          app_namespace: "NAMESPACE"
          app_collection_repo: "COLLECTION-app-collection"
          requires:
            # Make sure the chart bechind the app is in the app catalog.
            - push-REPOSITORY-to-CATALOG-app-catalog
          filters:
            # Do not trigger the job on commit.
            branches:
              ignore: /.*/
            # Trigger job also on git tag.
            tags:
              only: /^v.*/
```

**NOTE**: There is a known issue produced by a race condition which produces a failed build with the following output.

```text
To github.com:giantswarm/aws-app-collection.git
 ! [rejected]        master -> master (fetch first)
error: failed to push some refs to 'git@github.com:giantswarm/aws-app-collection.git'
hint: Updates were rejected because the remote contains work that you do
hint: not have locally. This is usually caused by another repository pushing
hint: to the same ref. You may want to first integrate the remote changes
hint: (e.g., 'git pull ...') before pushing again.
hint: See the 'Note about fast-forwards' in 'git push --help' for details.
Exited with code 1
```

Integrating the remote changes and the push is already retried a couple of times so this should be very rare, but in case it does happen triggering the build again should solve the issue.

