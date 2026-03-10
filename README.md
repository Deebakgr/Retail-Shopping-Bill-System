# Retail-Shopping-Bill-System
Retail Shopping Bill System (Managed Scenario) – ABAP RAP
Project Overview

The Retail Shopping Bill System is an ABAP RESTful Application Programming Model (RAP) application developed using the Managed Scenario. The system is designed to help retail shops generate bills for customers efficiently. It allows users to manage product details, calculate billing amounts automatically, and generate retail invoices.

This application demonstrates how RAP can be used to build modern Fiori-based transactional applications with minimal manual coding by leveraging the managed behavior implementation provided by the RAP framework.

Objectives

The main objectives of this project are:

To automate retail billing operations.

To demonstrate the implementation of ABAP RAP Managed Scenario.

To create a Fiori Elements based UI for retail billing.

To manage product and billing data efficiently.

To automatically handle CRUD operations using RAP managed behavior.

Technologies Used

ABAP RAP (RESTful Application Programming Model)

Core Data Services (CDS)

Behavior Definition (Managed Implementation)

Behavior Projection

Service Definition

Service Binding (OData V4)

SAP Fiori Elements

System Architecture

The application follows the RAP architecture:

Database Table

Stores retail bill data such as bill ID, product name, quantity, price, and total amount.

Interface CDS View

Represents the business object interface layer.

Projection CDS View

Used for UI consumption.

Behavior Definition (Managed)

Handles CRUD operations automatically.

Service Definition

Exposes the business object.

Service Binding

Connects the service to Fiori UI via OData.

Key Features

Product selection for billing

Automatic bill generation

Quantity-based price calculation

CRUD operations for bill records

Fiori-based UI for easy interaction

Managed scenario for simplified development

Data Fields
Field Name	Description
Bill_ID	Unique identifier for each bill
Product_Name	Name of the product
Quantity	Number of items purchased
Price	Price per product
Total_Amount	Total bill amount
