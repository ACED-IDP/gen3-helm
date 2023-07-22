# ACED Role Based Access Control

## Use case

There are several institutions that are contributing data to ACED. Each institution has a different set of data access policies. 
Each may have different requirements for how data is accessed, and who can access it. 
Importantly, each institution may have individual who approves access to data.

## Solution

We use Gen3's role based access control (RBAC) to manage access to data.

* There is a separate `program` resource for each institution:
  * /programs/ohsu
  * /programs/stanford
  * /programs/ucl
  * /programs/manchester

* There is a separate requestor `policy` for each program. "Update" in this context means setting the status of a user's request to [SIGNED].
  * ohsu_requestor_updater_role
  * stanford_requestor_updater_role
  * ucl_requestor_updater_role
  * manchester_requestor_updater_role

Since this approach relies on Gen3's [Requestor](https://github.com/uc-cdis/requestor/blob/master/docs/functionality_and_flow.md#example-backend-flow) for all assignments of policies to users we get  the following benefits:
* Tooling (command line for now, web page in the future) leverages requestor API
* Auditing of data access requests is done by requestor

## Implementation

### Adding Data Access Committee members

* A sysadmin will add the ohsu_requestor_updater_role  to a data-access-committee member(s)
* Only users with the ohsu_requestor_updater_role  can APPROVE and SIGN adding policies

```text
#  sysadmin adds role to user
gen3_util access touch <data-access-committee>@ohsu.edu /programs/ohsu --roles ohsu_requestor_updater_role
#  sysadmin SIGNs the request
gen3_util access <request-ids> SIGNED
```

### Creating a new project

* Any user may request a project be added to the institution's program.
* The user who requested the project is automatically given the read and write roles.
 
```text
# add requestor read and write policies to resource /programs/ohsu/projects/test
gen3_util projects add resource ohsu-test
```

* Ony user's with the ohsu_requestor_updater_role  can approve and sign a request

```text
gen3_util access <request-ids> SIGNED
```

### Adding a new user to a project

* Any user may request a user be added to a project.
* The `--write` flag will grant the user write access to the project.
 
```text
# add requestor read and write policies to resource /programs/ohsu/projects/test
gen3_util projects add user user@example.com ohsu-test
```

* Ony user's with the ohsu_requestor_updater_role  can approve and sign a request

```text
gen3_util access <request-ids> SIGNED
```


## Configuration

```yaml
      authz:
        # policies automatically given to anyone, even if they are not authenticated
        anonymous_policies: []

        # policies automatically given to authenticated users (in addition to their other policies)
        all_users_policies:
        - requestor_creator  # all users can create a request for data access

        groups:

        # preconfigured roles for system admins
        - name: administrators
          policies:
          - services.sheepdog-admin  # CRUD operations on programs and projects
          - data_upload              # upload data files
          - indexd_admin             # CRUD operations on data files
          - requestor_creator        # create requests for data access
          - requestor_updater        # approve and sign requests for data access
          - requestor_reader         # read all requests for data access
          - sower_user               # submit jobs to sower
          - workspace                # future: use workspace (notebooks, etc)
          users: []
          # ADMIN USER EMAILS GO HERE


        resources:
        - name: workspace  # notebooks, etc
        - name: data_file  # indexd
        - name: sower      # jobs
        - name: services   # sheepdog
          subresources:
          - name: sheepdog
            subresources:
            - name: submission
              subresources:
              - name: program
              - name: project
        - name: programs   # institutions
          subresources:
          - name: ohsu
            subresources:  # studies added by requestor 
            - name: projects
          - name: ucl
            subresources:
            - name: projects
          - name: manchester
            subresources:
            - name: projects
          - name: stanford
            subresources:
            - name: projects


        policies:

        - id: workspace
          description: be able to use workspace
          resource_paths:
          - /workspace
          role_ids:
          - workspace_user

        - id: data_upload
          description: upload raw data files to S3
          role_ids:
          - file_uploader
          resource_paths:
          - /data_file

        - id: services.sheepdog-admin
          description: CRUD access to programs and projects
          role_ids:
            - sheepdog_admin
          resource_paths:
            - /services/sheepdog/submission/program
            - /services/sheepdog/submission/project

        - id: indexd_admin
          description: full access to indexd API
          role_ids:
            - indexd_admin
          resource_paths:
            - /programs
            - /data_file

        # REQUESTOR POLICIES
        - id: requestor_creator
          description: Allows requesting access to any resource under "/programs"
          role_ids:
            - requestor_creator_role
          resource_paths:
            - /programs
            - /sower      

        - id: requestor_updater
          description: Allows approving access to ALL resource under "/programs"
          role_ids:
            - requestor_updater_role
          resource_paths:
            - /programs
            - /sower      

        - id: ohsu_requestor_updater
          description: Allows approving access to any resource under "/programs/ohsu"
          role_ids:
            - ohsu_requestor_updater_role
          resource_paths:
            - /programs/ohsu

        - id: ucl_requestor_updater
          description: Allows approving access to any resource under "/programs/ucl"
          role_ids:
            - ucl_requestor_updater_role
          resource_paths:
            - /programs/ucl

        - id: manchester_requestor_updater
          description: Allows approving access to any resource under "/programs/manchester"
          role_ids:
            - manchester_requestor_updater_role
          resource_paths:
            - /programs/manchester

        - id: stanford_requestor_updater
          description: Allows approving access to any resource under "/programs/stanford"
          role_ids:
            - stanford_requestor_updater_role
          resource_paths:
            - /programs/stanford


        - id: requestor_reader
          description: read all requests
          role_ids:
            - requestor_reader_role
          resource_paths:   # allows on programs and sower
            - /programs
            - /sower      

        # jobs (sower)
        - description: be able to use sower job
          id: sower
          resource_paths: [/sower]
          role_ids: [sower_user]


        roles:
        - id: file_uploader
          permissions:
          - id: file_upload
            action:
              service: fence
              method: file_upload
        - id: workspace_user
          permissions:
          - id: workspace_access
            action:
              service: jupyterhub
              method: access
        - id: sheepdog_admin
          description: CRUD access to programs and projects
          permissions:
          - id: sheepdog_admin_action
            action:
              service: sheepdog
              method: '*'
        - id: indexd_admin
          description: full access to indexd API
          permissions:
          - id: indexd_admin
            action:
              service: indexd
              method: '*'
        - id: admin
          permissions:
            - id: admin
              action:
                service: '*'
                method: '*'
        - id: creator
          permissions:
            - id: creator
              action:
                service: '*'
                method: create
        - id: reader
          permissions:
            - id: reader
              action:
                service: '*'
                method: read
        - id: updater
          permissions:
            - id: updater
              action:
                service: '*'
                method: update
        - id: deleter
          permissions:
            - id: deleter
              action:
                service: '*'
                method: delete
        - id: storage_writer
          permissions:
            - id: storage_creator
              action:
                service: '*'
                method: write-storage
        - id: storage_reader
          permissions:
            - id: storage_reader
              action:
                service: '*'
                method: read-storage

        # REQUESTOR ROLES
        - id: requestor_creator_role
          permissions:
            - id: requestor_creator_action
              action:
                service: requestor
                method: create

        - id: requestor_updater_role
          permissions:
            - id: requestor_updater_action
              action:
                service: requestor
                method: update


        - id: ohsu_requestor_updater_role
          permissions:
            - id: ohsu_requestor_updater_action
              action:
                service: requestor
                method: update

        - id: ucl_requestor_updater_role
          permissions:
            - id: ucl_requestor_updater_action
              action:
                service: requestor
                method: update

        - id: manchester_requestor_updater_role
          permissions:
            - id: manchester_requestor_updater_action
              action:
                service: requestor
                method: update

        - id: stanford_requestor_updater_role
          permissions:
            - id: stanford_requestor_updater_action
              action:
                service: requestor
                method: update


        - id: requestor_reader_role
          permissions:
            - id: requestor_reader_action
              action:
                service: requestor
                method: read

        # jobs (sower)
        - id: sower_user
          permissions:
            - id: sower_access
              action:
                service: job
                method: access

      clients:
        wts:
          policies: []

      users: {}
      # ADMIN USER EMAILS GO HERE
        


   cloud_providers: {}
   groups: {}
```