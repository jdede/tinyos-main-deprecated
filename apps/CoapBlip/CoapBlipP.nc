/*
 * Copyright (c) 2011 University of Bremen, TZI
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the
 *   distribution.
 * - Neither the name of the copyright holders nor the names of
 *   its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL
 * THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include <IPDispatch.h>
#include <lib6lowpan/lib6lowpan.h>
#include <lib6lowpan/ip.h>
#include "blip_printf.h"
#ifdef COAP_CLIENT_ENABLED
#include "tinyos_net.h"
#endif

module CoapBlipP {
  uses {
    interface Boot;
    interface SplitControl as RadioControl;
    interface Leds;

#ifdef COAP_SERVER_ENABLED
    interface CoAPServer;
#ifdef COAP_RESOURCE_KEY
    interface Mount;
#endif
#endif

#ifdef COAP_CLIENT_ENABLED
    interface CoAPClient;
    interface ForwardingTableEvents;
#ifdef TOSSIM
  interface Timer<TMilli> as TimerSim;
#endif
#endif
#ifdef TOSSIM
#ifdef RPL_ROUTING
    interface RootControl;
#endif
#endif
  }

  provides interface Init;

} implementation {
#ifdef COAP_CLIENT_ENABLED
  struct sockaddr_in6 sa6;
  uint8_t node_integrate_done = FALSE;
//  coap_list_t *optlist = NULL;

#endif

  command error_t Init.init() {
    return SUCCESS;
  }

  event void Boot.booted() {
#ifdef COAP_SERVER_ENABLED
    uint8_t i;
#endif
    call RadioControl.start();
    printf("booted %i start\n", TOS_NODE_ID);
#ifdef COAP_SERVER_ENABLED
#ifdef COAP_RESOURCE_KEY
    if (call Mount.mount() == SUCCESS) {
      printf("CoapBlipP.Mount successful\n");
    }
#endif
    // needs to be before registerResource to setup context:
    call CoAPServer.bind(COAP_SERVER_PORT);

    call CoAPServer.registerWellknownCore();
    for (i=0; i < NUM_URIS; i++) {
      call CoAPServer.registerResource(uri_key_map[i].uri,
				       uri_key_map[i].urilen - 1,
				       uri_key_map[i].mediatype,
				       uri_key_map[i].writable,
				       uri_key_map[i].splitphase,
				       uri_key_map[i].immediately);
    }
#endif

#ifdef TOSSIM
#ifdef RPL_ROUTING
    if (TOS_NODE_ID == NODE1_ID) {
      dbg ("UDPEchoP", "Root ID = %d.\n", TOS_NODE_ID);
      call RootControl.setRoot();
      call TimerSim.startOneShot(WAITTIME);
      inet_pton6(COAP_CLIENT_DEST, &sa6.sin6_addr);
      sa6.sin6_port = htons(COAP_CLIENT_PORT);
    }
#endif
#endif

  }

#if defined (COAP_SERVER_ENABLED) && defined (COAP_RESOURCE_KEY)
  event void Mount.mountDone(error_t error) {
  }
#endif

  event void RadioControl.startDone(error_t e) {
    printf("radio startDone: %i\n", TOS_NODE_ID);
  }

  event void RadioControl.stopDone(error_t e) {
  }

#ifdef COAP_CLIENT_ENABLED
  event void ForwardingTableEvents.defaultRouteAdded() {
    struct sockaddr_in6 sa6;
    coap_list_t *optlist = NULL;

    if (node_integrate_done == FALSE) {
      node_integrate_done = TRUE;

      inet_pton6(COAP_CLIENT_DEST, &sa6.sin6_addr);
      sa6.sin6_port = htons(COAP_CLIENT_PORT);

#ifdef TOSSIM
    dbg ("Coap", "Default Route added on ID = %d.\n", TOS_NODE_ID);
#endif

      coap_insert( &optlist, new_option_node(COAP_OPTION_URI_PATH, sizeof("ni") - 1, "ni"), order_opts);

      call CoAPClient.request(&sa6, COAP_REQUEST_PUT, optlist, 0, NULL);
    }
  }

#ifdef TOSSIM
  event void TimerSim.fired() {
    dbg ("Coap", "TimerSim fired!!\n");
    optlist = NULL;
    coap_insert( &optlist, new_option_node(COAP_OPTION_URI_PATH, sizeof("l") - 1, "l"), order_opts);

    call CoAPClient.request(&sa6, COAP_REQUEST_GET, optlist, 0, 0);

    call TimerSim.startPeriodic(1024 * COAP_CLIENT_SEND_RI_INTERVAL);
  }
#endif

  event void ForwardingTableEvents.defaultRouteRemoved() {
  }

  event error_t CoAPClient.streamed_next_block (uint16_t blockno, uint16_t *len, void **data)
  {
    return FAIL;
  }

  event void CoAPClient.request_done(uint8_t code, uint8_t mediatype, uint16_t len, void *data, bool more) {
    //TODO: handle the request_done
  };
#endif

  }
