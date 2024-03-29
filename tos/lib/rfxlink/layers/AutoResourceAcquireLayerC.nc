/*
 * Copyright (c) 2009, Vanderbilt University
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
 * - Neither the name of the copyright holder nor the names of
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
 *
 * Author: Miklos Maroti
 */

generic module AutoResourceAcquireLayerC()
{
	provides
	{
		interface BareSend;
	}

	uses
	{
		interface BareSend as SubSend;
		interface Resource;
	}
}

implementation
{
	message_t *pending;

	command error_t BareSend.send(message_t* msg)
	{
		if( call Resource.immediateRequest() == SUCCESS )
		{
			error_t result = call SubSend.send(msg);
			if( result != SUCCESS )
				call Resource.release();
	
			return result;
		}

		pending = msg;
		return call Resource.request();
	}

	event void Resource.granted()
	{
		error_t result = call SubSend.send(pending);
		if( result != SUCCESS )
		{
			call Resource.release();
			signal BareSend.sendDone(pending, result);
		}
		dbg("Bo-AutoResource","AutoResource:Send.\n");
	}

	event void SubSend.sendDone(message_t* msg, error_t result)
	{
		call Resource.release();
		signal BareSend.sendDone(msg, result);
		dbg("Bo-AutoResource","AutoResource:Send Done.\n");
	}

	command error_t BareSend.cancel(message_t* msg)
	{
		return call SubSend.cancel(msg);
	}
}
