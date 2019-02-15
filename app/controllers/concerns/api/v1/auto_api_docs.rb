module Api::V1::AutoApiDocs
  extend ActiveSupport::Concern

  class_methods do
    def mock_controller
      new
    end

    def model_class
      mock_controller.send(:model_class)
    end

    def params!
      columns = model_class.column_names - mock_controller.send(:forbidden_write_columns).map(&:to_s)
      columns.each do |column|
        validator = case model_class.columns_hash[column].type
                    when :integer, :bigint
                      Integer
                    else
                      String
                    end
        param column, validator
      end
    end

    def structure!
      description <<-DOC
      This API method describes the structure of #{model_class.name.pluralize}.
      The output +data+ is an Array, and each item of the Array is an Object describing each column/field.
      This Object contains the following keys:

      - +name+ – Name of the column/field
      - +type+ – Type of the column/field. Known types:
        - +integer+ – Real number without a decimal
        - +string+ – Value shows up as a string, but internally may be a varchar or a text.
        - +primary_key+ – Like an +integer+, but is the one column/field that uniquely identifies the record
          The +name+ is very likely to be "id".
        - +datetime+ – Value shows up as the ISO 8601 string representation of an internally stored datetime
        - +enum+ – Value shows up as a +string+, but internally, it's mapped to an integer
        - +foreign_key+ – Value shows up as an +integer+, but it's the "id" (primary key) of a different kind of record to which this record belongs
      - +limit+ – The maximum length of the internal field type. +null+ if this is not applicable (like to the +datetime+ type).
        For fields that are integers internally, this is the display width or maximum number of digits that the integer can be.
        For fields that are strings internally, this is the character limit.
      - +readable?+ – +true+ if the value of this column/field can be read with a GET request in the standard CRUD operations. +false+ otherwise
      - +writable?+ – +true+ if the value of this column/field can be set with a POST/PATCH/PUT request in the standard CRUD operations. +false+ otherwise
      - +accessible?+ – +false+ if the value of this column/field is neither readable nor writable using any of the standard CRUD operations.
        +true+ if the value of column/field is readable, writable, or both, using any of the standard CRUD operations

      In addition to the keys above, the following keys may appear under certain conditions:
      - +enum+ – Only appears if +type+ is "enum".
        The value is an Object where the keys are the string representations of the integer values stored internally
      - +foreign_key+ – Only appears if +type+ is "foreign_key". The value is an Object with the following keys:
        - +name+ – The singular internal name of the foreign record
        - +plural_name+ – The plural internal name of the foreign record
      DOC

      formats ['JSON']

      route = Apipie.routes_for_action(self, :structure, desc: nil, options: nil).first
      mock = mock_controller
      mock.structure
      example("# #{route[:verb]} #{route[:path]}\n" +
                  JSON.pretty_generate(data: mock.instance_variable_get(:@data)))
    end

    def collection!
      columns = model_class.column_names - mock_controller.send(:forbidden_read_columns).map(&:to_s)

      description <<-DOC
      This API method provides a list (collection) of records, which can be *paginated*, *sorted*, *searched*, and *filtered* according to the provided params, all of which are optional.

      Default settings if no params are specified:
      - *Pagination:* Page 1 with a server-configured number of results per page
      - <b>Sort order:</b> Unspecified, probably in ascending order of each record's internal ID
      - *Search:* None
      - *Filters:* None

      === Pagination
      Navigate to different pages and/or change how many records are in a page.
      ==== Input Params
      The following input params are optional. The server default value will be used for each param not provided.
      - +page+ – Page number, starting from 1
      - +per_page+ – Records per page
      ==== Output Metadata
      - +pagination+ – Object complete with information about pagination position. Keys:
        - +records_count+ – Total number of records after search and filters
        - +pages_count+ – Number of pages of results
        - +records_per_page+ – Maximum number of records in the +data+ Array
        - +first_page?+ – +true+ if the +data+ Array is presenting the first page. +false+ otherwise
        - +last_page?+ – +true+ if the +data+ Array is presenting the last page. +false+ otherwise
        - +previous_page_number+ – The page number before the current page or +null+ if the current page is the first page.
          May display an out of bounds page number if the current page is also out of bounds.
        - +current_page_number+ – The page number requested by the client, which may or may not be out of bounds
        - +next_page_number+ – The page number after the current page or +null+ if there is no next page
        - +out_of_bounds?+ – +true+ if the requested page number is between 1 and +pages_count+. +false+ otherwise
        - +offset+ – The number of records skipped before the first record in the +data+ Array

      === Order
      Sort the resultant records.
      ==== Input Params
      Zero or more of the following, applied in the order they are defined in the request:
      #{columns.map do |column|
          "- <code>order[#{column}]</code> – \"asc\" to sort column +#{column}+ in ascending order" \
              " or \"desc\" to sort +#{column}+ in descending order"
        end .join("\n      ")}
      ==== Output Metadata
      - +order+ – Array of sort fields and directions in the order they were received.
        Each Array item contains a Object of:
        - +field+ – The sorted field name
        - +direction+ – Either "asc" or "desc" to mean sorted ascending or sorted descending, respectively

      === Search
      Search multiple fields for a partial string and return all results with any matches.
      ==== Input Params
      Both of the following input params must be provided to apply a search:
      - <code>search[fields]</code> – A comma-delimited list of fields on which a partial match search will run.
        Possible fields: +#{columns.join('+, +')}+
      - <code>search[query]</code> – A case-insensitive string to match in any part of the fields specified.
        For example, a value of "BROWN" will match "A quick brown fox" if the latter string appears in any of the provided fields
      ==== Output Metadata
      - +search+ – Object containing the following keys:
        - +fields+ – Array of fields queried for partial matches
        - +query+ – Case-insensitive string used to find partial matches in the specified fields

      === Filters
      "Where" clause filters constrain the query to return results matching the specified conditions.

      For each record, _any_ *filter* that matches makes its <b>filter group</b> evaluate to true.
      _All_ <b>filter groups</b> must evaluate to true in order to select the record.
      ==== Input Params
      Not providing the +filters+ param means that filters will not be applied.
      - +filters+ – Object. Each item in this Object is called a <b>filter group</b>.
        It doesn't matter what +FILTER_GROUP_NAME+ is, but each unique +FILTER_GROUP_NAME+ represents a filter group.
        Filter groups are combined with +AND+ in the query generation process. Each filter group is:
        - <code>filters[FILTER_GROUP_NAME]</code> – Array. Each item in this Array is called a *filter*.
          Filters are combined with +OR+ in the query generation process. Each filter is structured like so:
          - <code>filters[FILTER_GROUP_NAME][]</code> – Value in the format of <code>{FIELD}{OPERATOR}{OPERAND}</code>

      <code>{FIELD}</code> is the name of the field to be filtered. Possible fields: +#{columns.join('+, +')}+

      <code>{OPERATOR}</code> is one of the following:
      - <code>=</code> – equals
      - <code><></code> – not equals
      - <code>></code> – greater than
      - <code>>=</code> – greater than or equals
      - <code><</code> – less than
      - <code><=</code> – less than or equals

      The <code>{OPERATOR}</code> applies to the <code>{OPERAND}</code>.
      If the <code>{OPERATOR}</code> is "=", the filter will look for an exact match of <code>{OPERAND}</code>.
      In this case, <code>{FIELD}</code> can be an enum internally and <code>{OPERAND}</code> will match the string/symbol representation of the enum.
      ==== Output Metadata
      - +filters+ – Array of filters and the way they were applied to modify the collection selection. Each item is:
        - Filter group – Array of filters. Each item is an Object consisting of these keys:
          - +key+ – The field to which this filter applied
          - +operation+ – The operator used in the filter:
            "=" (equals),
            "<>" (not equals),
            ">" (greater than),
            ">=" (greater than or equals),
            "<" (less than), or
            "<=" (less than or equals)
          - +value+ – The operand used in the filter
      DOC

      formats ['JSON']

      example <<-DOC
      # /api/v1/bmc_hosts?page=1&per_page=2&filters[0][]=zone_id>=1&filters[1][]=zone_id<=3&search[fields]=brand,product&search[query]=R410&order[serial]=asc
      #                   └┬───┘ └┬───────┘ └┬────────────────────┘ └┬────────────────────┘ └┬─────────────────────────┘ └┬───────────────┘ └┬──────────────┘
      #                    │      │          │                       │                       │                            │┌─────────────────┘
      #                    │      │          │                       │                       │ ┌──────────────────────────┘└ Sort by "serial" field ascending
      #                    │      │          │                       │                       │ └ Partial or full match for the string "R410"
      #                    │      │          │                       │                       └ Partial or full string search on fields "brand" and "product"
      #                    │      │          │                       └ The "zone_id" field of all returned results must be less than or equal to 3
      #                    │      │          └ The "zone_id" field of all returned results must be greater than or equal to 1
      #                    │      └ Show 2 records per page
      #                    └ Show page 1
      {
          "data": [
              {
                  "id": 5217,
                  "serial": "D4THT42",
                  "ip_address": "192.168.126.40",
                  "power_status": "off",
                  "sync_status": "success",
                  "system_id": null,
                  "created_at": "2010-12-08T10:34:54.000-08:00",
                  "updated_at": "2011-01-25T11:30:29.000-08:00",
                  "zone_id": 3,
                  "error_message": null,
                  "brand": "DELL",
                  "product": "PowerEdge R410",
                  "onboard_status": null,
                  "onboard_step": null,
                  "onboard_error_message": null,
                  "onboard_updated_at": null
              },
              {
                  "id": 5220,
                  "serial": "D4THT48",
                  "ip_address": "192.168.126.47",
                  "power_status": "off",
                  "sync_status": "success",
                  "system_id": null,
                  "created_at": "2010-12-08T10:34:54.000-08:00",
                  "updated_at": "2011-01-25T11:30:30.000-08:00",
                  "zone_id": 3,
                  "error_message": null,
                  "brand": "DELL",
                  "product": "PowerEdge R410",
                  "onboard_status": null,
                  "onboard_step": null,
                  "onboard_error_message": null,
                  "onboard_updated_at": null
              }
          ],
          "pagination": {
              "records_count": 2,
              "pages_count": 1,
              "records_per_page": 2,
              "first_page?": true,
              "last_page?": true,
              "previous_page_number": null,
              "current_page_number": 1,
              "next_page_number": null,
              "out_of_bounds?": false,
              "offset": 0
          },
          "search": {
              "fields": [
                  "brand",
                  "product"
              ],
              "query": "R410"
          },
          "filters": [
              [
                  {
                      "key": "zone_id",
                      "operation": ">=",
                      "value": "1"
                  },
              ],
              [
                  {
                      "key": "zone_id",
                      "operation": "<=",
                      "value": "3"
                  }
              ]
          ],
          "order": [
              {
                  "field": "serial",
                  "direction": "asc"
              }
          ]
      }
      DOC

      example <<-DOC
      # /api/v1/bmc_hosts?filters[group1][]=updated_at>=2023-03-23T14:46:00%2B00:00&filters[group1][]=zone_id=999999
      #                   └┬──────────────────────────────────────────────────────┘ └┬─────────────────────────────┘
      #                    │ ┌───────────────────────────────────────────────────────┘
      #                    │ └ The "zone_id" field of all returned results must be 999999 or…
      #                    └── the "updated_at" field of all returned results must be at or after 23 March 2023 at 14:46:00 UTC
      {
          "data": [
              {
                  "id": 1,
                  "serial": "CZ3402Y24T",
                  "ip_address": "192.168.1.65",
                  "power_status": "on",
                  "sync_status": "success",
                  "system_id": 6,
                  "created_at": "2014-04-13T14:29:12.000-05:00",
                  "updated_at": "2023-03-23T09:46:03.000-05:00",
                  "zone_id": 1,
                  "error_message": null,
                  "brand": "HP",
                  "product": "ProLiant DL160 Gen8",
                  "onboard_status": "success",
                  "onboard_step": "complete",
                  "onboard_error_message": null,
                  "onboard_updated_at": "2017-10-04T15:11:36.000-05:00"
              },
              {
                  "id": 2,
                  "serial": "CZ3341R2HJ",
                  "ip_address": "192.168.1.66",
                  "power_status": "on",
                  "sync_status": "success",
                  "system_id": 3,
                  "created_at": "2014-04-13T14:29:12.000-05:00",
                  "updated_at": "2023-03-23T09:46:07.000-05:00",
                  "zone_id": 1,
                  "error_message": null,
                  "brand": "HP",
                  "product": "ProLiant DL160 Gen8",
                  "onboard_status": "success",
                  "onboard_step": "complete",
                  "onboard_error_message": null,
                  "onboard_updated_at": "2017-10-04T15:11:36.000-05:00"
              }
          ],
          "pagination": {
              "records_count": 2,
              "pages_count": 1,
              "records_per_page": 10,
              "first_page?": true,
              "last_page?": true,
              "previous_page_number": null,
              "current_page_number": 1,
              "next_page_number": null,
              "out_of_bounds?": false,
              "offset": 0
          },
          "filters": [
              [
                  {
                      "key": "updated_at",
                      "operation": ">=",
                      "value": "2023-03-23T14:46:00+00:00"
                  },
                  {
                      "key": "zone_id",
                      "operation": "=",
                      "value": "999999"
                  }
              ]
          ]
      }
      DOC

      # Pagination
      param :page, Integer, desc: 'Page number, starting from 1'
      param :per_page, Integer, 'Desired maximum number of records per page'

      # Sort
      param :order, Hash, desc: <<-DOC
      One or more of the following keys:

      - +#{columns.join("+\n      - +")}+

      Value of each key must be +asc+ or +desc+, case-insensitive

      Sort order is processed in the order the keys are provided
      DOC

      # Magic Search
      param :search, Hash, desc: 'Search multiple fields for a partial string and return all results with any matches' do
        param :fields, String, desc: <<-DOC
        Comma-delimited list of fields to search.  Example containing all fields:

        <code>#{columns.join(',')}</code>
        DOC
        param :query, String, desc: 'A case-insensitive string to match partially in any of the specified +fields+'
      end

      # Filters
      param :filters, Hash, desc: 'Filter groups (explained in the "Search" section above)'
    end
  end
end