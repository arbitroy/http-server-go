package main

import (
	"log"

	"github.com/go-openapi/loads"
	"github.com/go-openapi/runtime/middleware"
	"github.com/scraly/http-go-server/pkg/swagger/server/restapi"

	"github.com/scraly/http-go-server/pkg/swagger/server/restapi/operations"
)

func main() {

	// Initialize Swagger
	swaggerSpec, err := loads.Analyzed(restapi.SwaggerJSON, "")
	if err != nil {
		log.Fatalln(err)
	}

	api := operations.NewHelloAPIAPI(swaggerSpec)
	server := restapi.NewServer(api)
	defer func(){
        if err:= server.Shutdown(); err != nil {
            // error handle
            log.Fatalln(err)
        }
    }()

	server.Port = 8081

    api.CheckHealthHandler = operations.CheckHealthHandlerFunc(
        func(user operations.CheckHealthParams) middleware.Responder{
            return operations.NewCheckHealthOK().WithPayload("OK")
    })

    api.GetHelloUserHandler = operations.GetHelloUserHandlerFunc(
        func(user operations.GetHelloUserParams) middleware.Responder {
            return operations.NewGetHelloUserOK().WithPayload("Hello "+user.User+"!")
    })
	// Start listening using having the handlers and port
	// already set up.
	if err := server.Serve(); err != nil {
		log.Fatalln(err)
	}
    
}
