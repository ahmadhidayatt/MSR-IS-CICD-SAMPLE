function jdbcAdapterConnPropValidator(theForm)
{
	if((theForm.elements['.CPROP.portNumber'] != "undefined") && (theForm.elements['.CPROP.portNumber'].value.length > 0) && (!isNumber(theForm.elements['.CPROP.portNumber'].value) || (parseInt(theForm.elements['.CPROP.portNumber'].value) < 0)))
		{
			return "Invalid Port Number.";
		}
	var portNum = parseInt(theForm.elements['.CPROP.portNumber'].value);
	if(portNum > 65535)
	{
		return "Invalid Port Number.";
	}
}
adapterConnPropValidator = jdbcAdapterConnPropValidator;