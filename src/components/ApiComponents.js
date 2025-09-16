import React from 'react';

export const ApiMethod = ({ name, signature, description, children }) => (
  <div className="api-method">
    <h4 className="api-method-name">{name}</h4>
    {signature && (
      <pre className="api-signature">
        <code>{signature}</code>
      </pre>
    )}
    {description && <p className="api-description">{description}</p>}
    {children}
  </div>
);

export const ApiProperty = ({ name, type, description, defaultValue }) => (
  <div className="api-property">
    <div className="api-property-header">
      <strong className="api-property-name">{name}</strong>
      {type && <em className="api-property-type">({type})</em>}
      {defaultValue && <span className="api-property-default">= {defaultValue}</span>}
    </div>
    {description && <p className="api-property-description">{description}</p>}
  </div>
);

export const ApiExample = ({ title = "Example", children }) => (
  <div className="api-example">
    <h5 className="api-example-title">{title}</h5>
    <div className="api-example-content">
      {children}
    </div>
  </div>
);

export const ApiClass = ({ name, namespace, description, children }) => (
  <div className="api-class">
    <div className="api-class-header">
      <h2 className="api-class-name">{name}</h2>
      {namespace && <span className="api-class-namespace">{namespace}</span>}
    </div>
    {description && <p className="api-class-description">{description}</p>}
    <div className="api-class-content">
      {children}
    </div>
  </div>
);

export const ApiParameters = ({ children }) => (
  <div className="api-parameters">
    <h6>Parameters:</h6>
    <div className="api-parameters-list">
      {children}
    </div>
  </div>
);

export const ApiParameter = ({ name, type, description, optional = false }) => (
  <div className="api-parameter">
    <code className="api-parameter-name">
      {name}{optional && '?'}
    </code>
    {type && <em className="api-parameter-type"> ({type})</em>}
    {description && <span className="api-parameter-description"> - {description}</span>}
  </div>
);

export const ApiReturns = ({ type, description }) => (
  <div className="api-returns">
    <h6>Returns:</h6>
    <div className="api-returns-content">
      {type && <code className="api-returns-type">{type}</code>}
      {description && <span className="api-returns-description"> - {description}</span>}
    </div>
  </div>
);