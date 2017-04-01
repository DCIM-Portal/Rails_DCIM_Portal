App.status = App.cable.subscriptions.create "StatusChannel",
  connected: ->
    # Called when the subscription is ready for use on the server

  disconnected: ->
    # Called when the subscription has been terminated by the server

  received: (data) ->
    # Called when there's incoming data on the websocket for this channel

    #Define Prettier Dates with Momentjs
    create_date = moment(data.created_at).format('MMM DD YYYY, h:mm A')
    update_date = moment(data.updated_at).format('MMM D YYYY, h:mm:ss A')

    #Send Alert Upon Channel Broadcast
    if `typeof data.status != 'undefined'`
      $.notify {
        title: "<span class='glyphicon glyphicon-list-alt'></span><strong> Scan Job #{ data.job_id } </strong>"
        message: "<span class='text-warning'><em> #{ data.status } </em></span> at #{ update_date }"
      },
      element: 'body'
      newest_on_top: false
      placement:
        from: 'bottom'
        align: 'right'
      offset: 20
      type: 'info'
      spacing: 5
      delay: 10000
      animate:
        enter: 'animated fadeInUp'
        exit: 'animated fadeOutDown'
      template: '<div data-notify="container" class="col-xs-11 col-sm-2 alert alert-{0}" role="alert">' +
                '<button type="button" aria-hidden="true" class="close" data-notify="dismiss">×</button>' +
                '<span data-notify="icon"></span> ' +
                '<span data-notify="title">{1}</span> ' +
                '<span data-notify="message">{2}</span>' + 
                '<div class="progress" data-notify="progressbar">' +
                '<div class="progress-bar progress-bar-{0}" role="progressbar" aria-valuenow="0" aria-valuemin="0" aria-valuemax="100" style="width: 0%;"></div>' +
                '</div>' +
                '<a href="{3}" target="{4}" data-notify="url"></a>' +
                '</div>'
    
    #Define various IDs
    detail_status = "#status_#{ data.job_id }"
    respond_message = "#scan_info_#{ data.job_id }"

    #Define various messages
    wait_status = "#{ data.status } <div class='throbber-loader'> </div>"
    wait_message = 'Waiting on scan results <div class="throbber-loader"> </div>'
    no_respond = 'No servers responded within this range'
    respond_finish = "#{ data.server_count } server(s) responded"

    #Remove periods from IDs that have IPv4 Addresses
    escapeSelector = (s) ->
      s.replace /\./g, "\\."

    #Define Jquery Datatables
    table = $('#dtable').DataTable() if $('#dtable').length
    detail_table = $('#detail_table').DataTable() if $('#detail_table').length

    if data.status == "Rescanning"
      detail_table?.rows( ".server#{ data.job_id }" ).remove().draw()

    #If job is created, make new row in Jquery datatables
    else if data.status == "Created" then (
      count = 0
      new_data = [
        data.job_id
        data.start_ip
        data.end_ip
        data.ilo_username
        data.ilo_password
        data.status
        create_date
        "<a class='btn btn-small btn-info' href='/ilo_scan_jobs/#{ data.job_id }'>Details</a>"
      ]
      new_row = table?.row.add(new_data).draw().nodes().to$().find('td').each ->
        $(this).attr 'id', 'td_' + count++ + '_' + data.job_id
      $( new_row ).css( 'display', 'none' )
      $( new_row ).fadeIn(500)
      id = $("#row#{ data.job_id }").val()
      table?.row(new_row).node().id = "row#{ data.job_id }"
    )

    #If job status is running
    else if data.status not in ['Created', 'Job Deleted', 'Scan Complete', 'Error During Provisioning', 'Servers Provisioned'] and `typeof data.serial == 'undefined'` then (

      #Update Jquery datatable if it exists
      table?.cell("#td_5_#{ data.job_id }").data wait_status

      #Update job detail status
      $(detail_status).html wait_status
    
      #Detail Status  
      if $(respond_message).length then (
        if ( data.count == null or data.server_count != 0 ) and data.status not in ['Provisioning Servers', 'Error During Provisioning', 'Servers Provisioned']
          $(respond_message).html wait_message
          $(respond_message).removeClass().addClass('waiting')
        else if data.server_count == 0
          $(respond_message).html no_respond
          $(respond_message).removeClass().addClass('no-respond')
      )

      #Add disabled class on buttons
      $("#edit_disable_#{ data.job_id }").addClass "disabled"
      $("#delete_disable_#{ data.job_id }").addClass "disabled"
      $(".provision_#{ data.job_id }").addClass "disabled"
    ) 

    #If job status is complete
    else if data.status == "Scan Complete" and `typeof data.serial == 'undefined'` then (

      #Update Jquery Datatable if it exists
      table?.cell("#td_5_#{ data.job_id }").data data.status

      #Update job detail status if it exists
      $(detail_status).html data.status

      #Detail Status  
      if $(respond_message).length then (
        if data.server_count == 0
          $(respond_message).html no_respond
        else if data.server_count != 0
          $(respond_message).html respond_finish
          $(respond_message).removeClass().addClass('responded')
      )

    #Remove disabled class on buttons
      $("#edit_disable_#{ data.job_id }").removeClass "disabled"
      $("#delete_disable_#{ data.job_id}").removeClass "disabled"
      $(".provision_#{ data.job_id}").removeClass "disabled"
    )

    else if data.status == "Error During Provisioning" || data.status == "Servers Provisioned"
      #Update Jquery Datatable if it exists
      table?.cell("#td_5_#{ data.job_id }").data data.status

      #Update job detail status if it exists
      $(detail_status).html data.status

      $("#edit_disable_#{ data.job_id }").removeClass "disabled"
      $("#delete_disable_#{ data.job_id}").removeClass "disabled"
      $(".provision_#{ data.job_id}").removeClass "disabled"

    #If job is deleted, remove table row from Jquery datatable
    else if data.status == "Job Deleted"
      tr = "#row" + data.job_id
      table?.row(tr).remove().draw()

    #If detail list is received
    if `typeof data.serial != 'undefined'` and $("#scan_#{ data.detail_id }").length and data.provision_status == 'Initial Scan' then (
      detail_count = 0
      detail_data = [
        data.address
        data.model
        data.serial
        data.power_status
        data.provision_status
      ]
      detail_row = detail_table?.row.add(detail_data).draw().nodes().to$().addClass("server#{ data.detail_id }")
      $('td:eq(4)', detail_row).attr 'id', "provision_#{ data.address }"
      $('td:eq(3)', detail_row).attr 'id', "power_#{ data.address }"
      $( detail_row ).css( 'display', 'none' )
      $( detail_row ).fadeIn(500)
    )

    if !(/((Initial Scan)|(Error)|(Completed: Discover))/.test(data.provision_status)) then (
      $("td#" + escapeSelector("provision_#{ data.address }") + " div.progress").show()
      detail_table?.cell("td#" + escapeSelector("provision_#{ data.address }")).data data.provision_status
      detail_table?.cell("td#" + escapeSelector("power_#{ data.address }")).data data.power_status
      $("td#" + escapeSelector("provision_#{ data.address }")).prepend(window.progress_bars[data.address])
    )
    else if (/((Error)|(Completed: Discover))/.test(data.provision_status))
      detail_table?.cell("td#" + escapeSelector("provision_#{ data.address }")).data data.provision_status
      $("td#" + escapeSelector("provision_#{ data.address }")).prepend(window.progress_bars[data.address])
      # XXX: Rework this when ScanResult is remodeled
      $("td#" + escapeSelector("provision_#{ data.address }")).find('div:contains("Server Discovered into Backend")').addClass('prov_message').removeClass('progress_finish')
      setTimeout( ->
        window.progress_bars[data.address].hide()
        # XXX: Rework this when ScanResult is remodeled
        $("td#" + escapeSelector("provision_#{ data.address }")).find('div:contains("Server Discovered into Backend")').addClass('progress_finish').removeClass('prov_message')
      , 3000)

    # Handle progress bar
    if data.status_address
      progress_bar = window.progress_bars[data.status_address].find('.progress-bar')
      # Convert indeterminate bar to determinate
      if progress_bar.hasClass('active')
        progress_bar.css 'width', "#{ data.percent }%"
        progress_bar.removeClass('active progress-bar-striped')
      # Animate progress bar to received percentage
      progress_bar.stop().animate { width: "#{ data.percent }%" }, 500
      progress_bar.html(data.percent + "%")
