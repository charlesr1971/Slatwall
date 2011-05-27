/*

    Slatwall - An e-commerce plugin for Mura CMS
    Copyright (C) 2011 ten24, LLC

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
    
    Linking this library statically or dynamically with other modules is
    making a combined work based on this library.  Thus, the terms and
    conditions of the GNU General Public License cover the whole
    combination.
 
    As a special exception, the copyright holders of this library give you
    permission to link this library with independent modules to produce an
    executable, regardless of the license terms of these independent
    modules, and to copy and distribute the resulting executable under
    terms of your choice, provided that you also meet, for each linked
    independent module, the terms and conditions of the license of that
    module.  An independent module is a module which is not derived from
    or based on this library.  If you modify this library, you may extend
    this exception to your version of the library, but you are not
    obligated to do so.  If you do not wish to do so, delete this
    exception statement from your version.

Notes:

*/
component persistent="false" accessors="true" output="false" extends="BaseController" {

	property name="accountService" type="any";
	property name="orderService" type="any";
	property name="paymentService" type="any";
	property name="settingService" type="any";
	
	public void function detail(required struct rc) {
		param name="rc.accountID" default="";
		param name="rc.shippingAddressID" default="";
		param name="rc.paymentAddressID" default="";
		param name="rc.paymentID" default="";
		
		// Insure that the cart is not new, and that it has order items in it.  otherwise redirect to the shopping cart
		if(rc.$.slatwall.cart().isNew() || !arrayLen(rc.$.slatwall.cart().getOrderItems())) {
			getFW().redirectExact(rc.$.createHREF('shopping-cart'));
		}
		
		// Setup all of the objects for their views
		rc.countriesArray = getSettingService().listCountry();
		
		if( rc.accountID != "" ) {
			rc.account = getAccountService().getAccount(rc.accountID, true);
		} else if ( !isNull(rc.$.slatwall.cart().getAccount()) ) {
			rc.account = rc.$.slatwall.cart().getAccount();
		} else {
			rc.account = getAccountService().newAccount();
		}
		
		if(rc.shippingAddressID != "") {
			rc.shippingAddress = getAccountService().getAddress(rc.shippingAddressID, true);	
		} else if (!isNull(rc.$.slatwall.cart().getOrderShippings()[1].getAddress())) {
			rc.shippingAddress = rc.$.slatwall.cart().getOrderShippings()[1].getAddress();
		} else {
			rc.shippingAddress = getAccountService().newAddress();
		}
		
		
		rc.payment = getOrderService().getOrderPayment(rc.paymentID, true);
		
		
		// Populate order Shipping Methods if needed.
		rc.$.slatwall.cart().getOrderShippings()[1].populateOrderShippingMethodOptionsIfEmpty();
	}
	
	public void function saveAccount(required struct rc) {
		detail(rc);
		
		rc.account = getAccountService().saveAccount(rc.account, rc);
		
		if(!rc.account.hasErrors()) {
			rc.$.slatwall.cart().setAccount(rc.account);
		}
		
		getFW().setView("frontend:checkout.detail");
	}
	
	public void function saveShippingAddress(required struct rc) {
		detail(rc);
		
		rc.shippingAddress = getAccountService().save(rc.shippingAddress,rc);
		
		if(!rc.shippingAddress.hasErrors()) {
			rc.$.slatwall.cart().getOrderShippings()[1].setAddress(rc.shippingAddress);
		}
		
		// Populate order Shipping Methods if needed.
		rc.$.slatwall.cart().getOrderShippings()[1].populateOrderShippingMethodOptionsIfEmpty();
		
		getFW().setView("frontend:checkout.detail");
	}
	
	public void function saveShippingMethod(required struct rc) {
		param name="rc.orderShippingMethodOptionID" default="";
		
		detail(rc);
		
		getOrderService().setOrderShippingMethodFromMethodOptionID(orderShipping=rc.$.slatwall.cart().getOrderShippings()[1], orderShippingMethodOptionID=rc.orderShippingMethodOptionID);
		
		getFW().setView("frontend:checkout.detail");
	}
	
	public void function processOrder(required struct rc) {
		detail(rc);
		
		var orderProcessOK = false;
		
		if(rc.payment.isNew()) {
			rc.payment = getOrderService().new("SlatwallOrderPayment#rc.paymentMethodID#");
		}
		
		// Populate and Validate Payment
		rc.payment = getPaymentService().populateAndValidateOrderPayment(rc.payment, rc);
		
		// If Payment has no errors than attach to order and process the order
		if(!rc.payment.hasErrors()) {
			rc.payment.setAmount(rc.$.slatwall.cart().getTotal());
			rc.$.slatwall.cart().addOrderPayment(rc.payment);
			orderProcessOK = getOrderService().processOrder(rc.$.slatwall.cart());
		}
		
		if(orderProcessOK) {
			// Redirect to order Confirmation
			getFW().redirectExact($.createHREF(filename='my-account'), false);
		}
		
		getFW().setView("frontend:checkout.detail");
	}
}